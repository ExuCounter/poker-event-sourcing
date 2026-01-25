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

      {:ok,
       assign(socket,
         table_id: table_id,
         lobby: lobby,
         game_view: game_view,
         current_user_id: socket.assigns.current_scope.user.id,
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

  def handle_event("event_processed", %{"eventId" => processed_event_id}, socket) do
    remaining_queue =
      Enum.reject(socket.assigns.queue, fn event -> event.event_id == processed_event_id end)

    game_view =
      Tables.get_player_game_view(
        socket.assigns.current_scope,
        socket.assigns.table_id,
        processed_event_id
      )

    socket = assign(socket, queue: remaining_queue)
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
    {amount, _} = Integer.parse(amount)

    case Tables.raise_hand(socket.assigns.current_scope, socket.assigns.table_id, amount) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("all_in_hand", _params, socket) do
    case Tables.all_in_hand(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("update_raise_amount", %{"raise_amount" => amount}, socket) do
    {amount_int, _} = Integer.parse(amount)

    {:noreply, assign(socket, raise_amount: amount_int)}
  end

  defp process_next_event(socket) do
    case socket.assigns.queue do
      [] ->
        assign(socket, current_animated_event_id: nil)

      [next_event | _rest] ->
        game_view =
          Tables.get_player_game_view(
            socket.assigns.current_scope,
            socket.assigns.table_id,
            next_event.event_id
          )

        next_event =
          if next_event.type == "ParticipantHandGiven" do
            participant =
              Enum.find(game_view.participants, &(&1.player_id == socket.assigns.current_user_id))

            if participant.id != next_event.participant_id do
              %{
                next_event
                | hole_cards: [nil, nil]
              }
            else
              next_event
            end
          else
            next_event
          end

        socket =
          push_event(socket, "table_event", %{
            event: JsonEncoder.transform_keys(next_event),
            new_state: JsonEncoder.transform_keys(game_view)
          })

        assign(socket,
          current_animated_event_id: next_event.event_id,
          raise_amount: nil
        )
    end
  end

  # Helper functions
  defp format_error(%{message: message}), do: message
  defp format_error(reason), do: "Action failed: #{inspect(reason)}"

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
        data-lobby={JsonEncoder.transform_keys(@lobby) |> Jason.encode!()}
        data-state={JsonEncoder.transform_keys(@game_view) |> Jason.encode!()}
        data-current-user-id={@current_user_id}
      />
      
    <!-- Action Controls - positioned and scaled -->
      <div
        class="origin-bottom-right absolute bottom-[16px] right-[16px]"
        style=" transform: scale(var(--game-scale, 0));"
      >
        <%= if Enum.any?(@game_view.valid_actions, fn {_key, value} -> value end) and is_nil(@current_animated_event_id) do %>
          <div class="bg-gray-900 rounded-2xl p-8 shadow-2xl border-2 border-gray-700 flex flex-col">
            
    <!-- Raise Controls -->
            <%= if @game_view.valid_actions.raise do %>
              <div class="flex flex-row gap-4 mb-5">
                <div class="flex gap-3 flex-wrap">
                  <%= for preset <- @game_view.valid_actions.raise.presets do %>
                    <button
                      type="button"
                      phx-click="update_raise_amount"
                      phx-value-raise_amount={preset.value}
                      class="bg-gray-700 hover:bg-gray-600 text-gray-300 text-md px-3 rounded"
                    >
                      {preset.label}
                    </button>
                  <% end %>
                </div>
                <div class="flex flex-col gap-2 flex-1">
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
                  <div class="flex justify-between text-md text-gray-500 font-bold">
                    <span>{@game_view.valid_actions.raise.min}</span>
                    <span>{@game_view.valid_actions.raise.max}</span>
                  </div>
                </div>
              </div>
            <% end %>

            <div class="flex gap-3 items-center">
              <!-- Fold Button -->
              <%= if @game_view.valid_actions.fold do %>
                <.button
                  phx-click="fold_hand"
                  class="bg-red-600 hover:bg-red-700 text-white font-bold px-8 py-4 rounded-lg text-base"
                >
                  Fold
                </.button>
              <% end %>
              <!-- Check Button -->
              <%= if @game_view.valid_actions.check do %>
                <.button
                  phx-click="check_hand"
                  class="bg-blue-600 hover:bg-blue-700 text-white font-bold px-8 py-4 rounded-lg text-base"
                >
                  Check
                </.button>
              <% end %>
              
    <!-- Call Button -->
              <%= if @game_view.valid_actions.call do %>
                <.button
                  phx-click="call_hand"
                  class="bg-green-600 hover:bg-green-700 text-white font-bold px-8 py-4 rounded-lg text-base"
                >
                  Call {@game_view.valid_actions.call.amount}
                </.button>
              <% end %>
              
    <!-- Raise Controls -->
              <%= if @game_view.valid_actions.raise do %>
                <.button
                  phx-click="raise_hand"
                  phx-value-amount={@raise_amount}
                  class="bg-yellow-600 hover:bg-yellow-700 text-white font-bold px-8 py-4 rounded-lg text-base"
                >
                  <div class="w-[120px] text-center">
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
    """
  end

  def normalized_table_type(:six_max), do: "6-max"
end
