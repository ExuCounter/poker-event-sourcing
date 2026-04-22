defmodule PokerWeb.PlayerLive.Game do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables
  alias PokerWeb.JsonEncoder

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    lobby = Tables.get_lobby(table_id)

    if is_nil(lobby) do
      {:ok,
       socket
       |> put_flash(:error, "Table not found")
       |> push_navigate(to: ~p"/")}
    else
      game_view =
        Tables.get_player_game_view(socket.assigns.current_scope, table_id)

      socket =
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
          socket
        else
          socket
        end

      current_participant =
        find_current_participant(game_view.participants, socket.assigns.current_scope.user.id)

      {:ok,
       assign(socket,
         table_id: table_id,
         game_view: game_view,
         current_user_id: socket.assigns.current_scope.user.id,
         current_participant: current_participant,
         is_participant: not is_nil(current_participant),
         raise_amount: nil,
         current_animated_event_id: nil,
         queue: []
       )}
    end
  end

  @impl true
  def handle_info({:table, _event, data}, socket) do
    socket = assign(socket, queue: socket.assigns.queue ++ [data])

    if is_nil(socket.assigns.current_animated_event_id) do
      socket = process_next_event(socket)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("event_processed", %{"streamVersion" => processed_stream_version}, socket) do
    remaining_queue =
      Enum.reject(socket.assigns.queue, fn event ->
        event.stream_version == processed_stream_version
      end)

    game_view =
      Tables.get_player_game_view(
        socket.assigns.current_scope,
        socket.assigns.table_id,
        processed_stream_version
      )

    current_participant =
      find_current_participant(game_view.participants, socket.assigns.current_user_id)

    socket = assign(socket, queue: remaining_queue, current_participant: current_participant)
    socket = process_next_event(socket)

    {:noreply, assign(socket, :game_view, game_view)}
  end

  # Action event handlers
  @impl true
  def handle_event("fold_hand", _params, socket) do
    case Tables.fold_hand(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("check_hand", _params, socket) do
    case Tables.check_hand(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("call_hand", _params, socket) do
    case Tables.call_hand(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("raise_hand", %{"amount" => amount}, socket) do
    case Integer.parse(amount) do
      {amount_int, _} ->
        case Tables.raise_hand(socket.assigns.current_scope, socket.assigns.table_id, amount_int) do
          :ok -> {:noreply, socket}
          {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Invalid raise amount")}
    end
  end

  def handle_event("all_in_hand", _params, socket) do
    case Tables.all_in_hand(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("update_raise_amount", %{"raise_amount" => amount}, socket) do
    case Integer.parse(amount) do
      {amount_int, _} ->
        {:noreply, assign(socket, raise_amount: amount_int)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("sit_out", _params, socket) do
    case Tables.sit_out_participant(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:ok, _} -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("sit_in", _params, socket) do
    case Tables.sit_in_participant(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:ok, _} -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("leave_table", _params, socket) do
    case Tables.leave_table(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "You have left the table")
         |> push_navigate(to: ~p"/tables/#{socket.assigns.table_id}/lobby")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  # Speed multipliers based on queue size thresholds
  # Format: {min_queue_size, multiplier} - :skip means instant jump
  @speed_multipliers [
    {45, :skip},
    {30, 0.50}
  ]

  defp process_next_event(socket) do
    case socket.assigns.queue do
      [] ->
        assign(socket, current_animated_event_id: nil)

      [next_event | _rest] ->
        game_view =
          Tables.get_player_game_view(
            socket.assigns.current_scope,
            socket.assigns.table_id,
            next_event.stream_version
          )

        # Apply dynamic timing based on queue size
        queue_size = length(socket.assigns.queue)
        adjusted_event = apply_dynamic_timing(next_event, queue_size)

        socket =
          push_event(socket, "table_event", %{
            event: JsonEncoder.transform_keys(adjusted_event),
            new_state: JsonEncoder.transform_keys(game_view)
          })

        assign(socket,
          current_animated_event_id: next_event.event_id,
          raise_amount: nil
        )
    end
  end

  defp apply_dynamic_timing(event, queue_size) do
    case get_speed_multiplier(queue_size) do
      :skip ->
        event
        |> Map.put(:skip_animation, true)
        |> put_in([:timing, :duration], 0)
        |> maybe_put_in([:timing, :stagger], 0)

      multiplier when is_number(multiplier) ->
        event
        |> update_in([:timing, :duration], &round(&1 * multiplier))
        |> maybe_update_in([:timing, :stagger], &round(&1 * multiplier))
    end
  end

  defp maybe_update_in(map, path, fun) do
    if get_in(map, path), do: update_in(map, path, fun), else: map
  end

  defp maybe_put_in(map, path, value) do
    if get_in(map, path), do: put_in(map, path, value), else: map
  end

  defp get_speed_multiplier(queue_size) do
    Enum.find_value(@speed_multipliers, 1.0, fn {threshold, multiplier} ->
      if queue_size >= threshold, do: multiplier
    end)
  end

  # Helper functions
  defp format_error(%{message: message}), do: message
  defp format_error(reason) when is_binary(reason), do: reason

  defp format_error(reason) when is_atom(reason) do
    case reason do
      :no_active_hand -> "No active hand in progress"
      :not_your_turn -> "It's not your turn to act"
      :participant_not_found -> "You are not a participant at this table"
      :insufficient_chips -> "Not enough chips for this action"
      :already_folded -> "You have already folded"
      :already_sat_out -> "You are already sitting out"
      :table_not_started -> "The table has not started yet"
      :table_finished -> "The table has finished"
      :table_already_finished -> "The table has already finished"
      :stale_timeout -> "Action already processed"
      :not_table_owner -> "Only the table owner can perform this action"
      :not_enough_participants -> "Not enough participants to start"
      :table_already_started -> "The table has already started"
      :cannot_leave_tournament -> "Cannot leave a tournament"
      _ -> "Action failed: #{reason}"
    end
  end

  defp format_error(reason), do: "Action failed: #{inspect(reason)}"

  defp find_current_participant(participants, player_id) when is_list(participants) do
    Enum.find(participants, fn p -> p.player_id == player_id end)
  end

  defp find_current_participant(_, _), do: nil

  @impl true
  def render(assigns) do
    # Initialize raise_amount from game_view if not set
    assigns =
      if is_nil(assigns.raise_amount) && assigns.game_view.valid_actions.raise do
        assign(assigns, raise_amount: assigns.game_view.valid_actions.raise.min)
      else
        assigns
      end

    ~H"""
    <.flash kind={:error} flash={@flash} />
    <.flash kind={:info} flash={@flash} />
    <div style="height: 100vh; position: relative; overflow: hidden;">
      <canvas
        id="poker-canvas"
        phx-hook="PokerCanvas"
        phx-update="ignore"
        data-state={JsonEncoder.transform_keys(@game_view) |> Jason.encode!()}
        data-current-user-id={@current_user_id}
      />


      <div style="transform: scale(var(--game-scale, 0)); transform-origin: bottom left; width: calc(100vw / var(--game-scale, 1));">

    <!-- Sit Out/In Button - bottom-left corner -->
        <%= if @current_participant do %>
          <div
            class="absolute left-5 bottom-5 z-10 flex"
            style="transform: scale(var(--button-boost, 1)); transform-origin: bottom left;"
          >
            <button
              phx-click={if @current_participant.is_sitting_out, do: "sit_in", else: "sit_out"}
              class={[
                "px-4 py-2 rounded-lg font-medium text-sm transition-all shadow-md hover:shadow-lg backdrop-blur-sm border",
                if(@current_participant.is_sitting_out,
                  do:
                    "bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white border-white/20",
                  else: "bg-amber-500/90 hover:bg-amber-600/95 text-white border-white/20"
                )
              ]}
            >
              <span class="flex items-center gap-1.5">
                <%= if @current_participant.is_sitting_out do %>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                    />
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Sit In
                <% else %>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Sit Out
                <% end %>
              </span>
            </button>
            <%= if @game_view.my_hand_rank do %>
              <div>
                <div class="px-3 py-1.5 rounded-lg">
                  <span class="text-amber-400 text-[12px] font-semibold">
                    {@game_view.my_hand_rank.display_name}
                  </span>
                </div>
              </div>
              <!-- Hand Rank Display - bottom-left corner, above sit out button -->
            <% end %>
          </div>
        <% end %>
        
    <!-- Action Controls - positioned and scaled -->
        <div
          class="absolute bottom-[16px] right-[16px]"
          style="transform: scale(var(--button-boost, 1)); transform-origin: bottom right;"
        >
          <%= if Enum.any?(@game_view.valid_actions, fn {_key, value} -> value end) and is_nil(@current_animated_event_id) do %>
            <div class="bg-gray-900 rounded-xl p-4 shadow-2xl border-2 border-gray-700 flex flex-col">
              
    <!-- Raise Controls -->
              <%= if @game_view.valid_actions.raise do %>
                <div class="flex flex-row gap-3 mb-3">
                  <div class="flex gap-2 flex-wrap">
                    <%= for preset <- @game_view.valid_actions.raise.presets do %>
                      <button
                        type="button"
                        phx-click="update_raise_amount"
                        phx-value-raise_amount={preset.value}
                        class="bg-gray-700 hover:bg-gray-600 text-gray-300 text-sm px-3 py-1.5 rounded"
                      >
                        {preset.label}
                      </button>
                    <% end %>
                  </div>
                  <div class="flex flex-col gap-0.5 flex-1">
                    <form phx-change="update_raise_amount">
                      <input
                        type="range"
                        name="raise_amount"
                        min={@game_view.valid_actions.raise.min}
                        max={@game_view.valid_actions.raise.max}
                        value={@raise_amount}
                        class="w-full h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-yellow-500"
                      />
                    </form>
                    <div class="flex justify-between text-sm text-gray-500 font-bold">
                      <span>{@game_view.valid_actions.raise.min}</span>
                      <span>{@game_view.valid_actions.raise.max}</span>
                    </div>
                  </div>
                </div>
              <% end %>

              <div class="flex gap-2 items-center">
                <!-- Fold Button -->
                <%= if @game_view.valid_actions.fold do %>
                  <.button
                    phx-click="fold_hand"
                    class="bg-red-600 hover:bg-red-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    Fold
                  </.button>
                <% end %>
                <!-- Check Button -->
                <%= if @game_view.valid_actions.check do %>
                  <.button
                    phx-click="check_hand"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    Check
                  </.button>
                <% end %>
                
    <!-- Call Button -->
                <%= if @game_view.valid_actions.call do %>
                  <.button
                    phx-click="call_hand"
                    class="bg-green-600 hover:bg-green-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    Call {@game_view.valid_actions.call.amount}
                  </.button>
                <% end %>
                
    <!-- Raise Controls -->
                <%= if @game_view.valid_actions.raise do %>
                  <.button
                    phx-click="raise_hand"
                    phx-value-amount={@raise_amount}
                    class="bg-yellow-600 hover:bg-yellow-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    <div class="w-[110px] text-center">
                      Raise {@raise_amount}
                    </div>
                  </.button>
                <% end %>
              </div>
            </div>
          <% end %>

          <div
            id="connection-status"
            phx-disconnected={JS.show()}
            phx-connected={JS.hide()}
            class="hidden absolute top-4 left-1/2 -translate-x-1/2 bg-yellow-600 text-white px-4 py-2 rounded-lg"
          >
            ⚠️ Disconnected - trying to reconnect...
          </div>
        </div>
      </div>
    </div>
    """
  end

  def normalized_table_type(:six_max), do: "6-max"
end
