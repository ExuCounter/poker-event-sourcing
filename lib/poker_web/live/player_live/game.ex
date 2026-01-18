defmodule PokerWeb.PlayerLive.Game do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables
  alias PokerWeb.AnimationDelays

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
          IO.inspect("CONNECTED - pushing init_state")
          Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
          socket |> push_event("init_state", game_view)
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

  def handle_event("event_processed", %{"event_id" => processed_event_id}, socket) do
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

        # socket = push_event(socket, "table_events", %{events: serialize_events([next_event])})
        socket =
          push_event(socket, "table_event", %{
            event: next_event |> Map.from_struct() |> Map.put(:type, event_type(next_event)),
            new_state: game_view
          })

        assign(socket,
          current_animated_event_id: next_event.event_id,
          raise_amount: nil
        )
    end
  end

  defp event_type(event) do
    event.__struct__
    |> Module.split()
    |> List.last()
  end

  # Serialize events for frontend with animation delays
  defp serialize_events(events) do
    Enum.map(events, fn event ->
      event_type = event.__struct__ |> Module.split() |> List.last()

      %{
        type: event_type,
        data: Map.from_struct(event),
        delay: AnimationDelays.for_event(event)
      }
    end)
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
    <canvas
      id="poker-canvas"
      phx-hook="PokerCanvas"
      phx-update="ignore"
      data-state={Jason.encode!(@game_view)}
      data-current-user-id={@current_user_id}
    >
    </canvas>

    <div>
      <div>
        <!-- Action Controls - Fixed to bottom -->
        <%= if not is_nil(@game_view.hand_id) and is_nil(@current_animated_event_id) do %>
          <div class="fixed bottom-8 right-7 bg-gray-900 rounded-2xl p-6 shadow-2xl border-2 border-gray-700">
            <%= if @game_view.valid_actions.fold do %>
              <div class="flex gap-4 items-center">
                <!-- Fold Button -->
                <.button
                  phx-click="fold_hand"
                  class="bg-red-600 hover:bg-red-700 text-white font-bold px-6 py-3 rounded-lg"
                >
                  Fold
                </.button>
                
    <!-- Check Button (only when no bet) -->
                <%= if @game_view.valid_actions.check do %>
                  <.button
                    phx-click="check_hand"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-bold px-6 py-3 rounded-lg"
                  >
                    Check
                  </.button>
                <% end %>
                
    <!-- Call Button (only when there's a bet) -->
                <%= if @game_view.valid_actions.call do %>
                  <.button
                    phx-click="call_hand"
                    class="bg-green-600 hover:bg-green-700 text-white font-bold px-6 py-3 rounded-lg"
                  >
                    Call {@game_view.valid_actions.call.amount}
                  </.button>
                <% end %>
                
    <!-- Raise Controls -->
                <%= if @game_view.valid_actions.raise do %>
                  <div class="flex flex-row gap-3">
                    <div>
                      <!-- Slider -->
                      <div class="flex flex-col gap-1 min-w-[250px] mt-[-4]">
                        <div class="flex justify-between items-center">
                          <span class="text-gray-400 text-xs">Raise Amount:</span>
                          <span class="text-yellow-400 font-bold text-sm">{@raise_amount}</span>
                        </div>
                        <form phx-change="update_raise_amount">
                          <input
                            type="range"
                            name="raise_amount"
                            min={@game_view.valid_actions.raise.min}
                            max={@game_view.valid_actions.raise.max}
                            value={@raise_amount}
                            phx-change="update_raise_amount"
                            class="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-yellow-500"
                          />
                        </form>
                        <div class="flex justify-between text-xs text-gray-500">
                          <span>{@game_view.valid_actions.raise.min}</span>
                          <span>{@game_view.valid_actions.raise.max}</span>
                        </div>
                      </div>
                      <!-- Quick Presets -->
                      <div class="flex gap-2 flex-wrap pt-4">
                        <%= for preset <- @game_view.valid_actions.raise.presets do %>
                          <button
                            type="button"
                            phx-click="update_raise_amount"
                            phx-value-raise_amount={preset.value}
                            class="bg-gray-700 hover:bg-gray-600 text-gray-300 text-xs px-2 py-1 rounded"
                          >
                            {preset.label}
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                  
    <!-- Custom Raise Button -->
                  <.button
                    phx-click="raise_hand"
                    phx-value-amount={@raise_amount}
                    class="bg-yellow-600 hover:bg-yellow-700 text-white font-bold px-6 py-3 rounded-lg"
                  >
                    <div class="w-[100px] text-center">
                      Raise {@raise_amount}
                    </div>
                  </.button>
                <% end %>
              </div>
            <% else %>
              <!-- Not your turn -->
              <div class="text-gray-400 text-lg font-semibold px-6 text-center">
                Waiting for other players...
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <div
        id="connection-status"
        phx-disconnected={JS.show()}
        phx-connected={JS.hide()}
        class="hidden"
      >
        ⚠️ Disconnected - trying to reconnect...
      </div>
    </div>
    """
  end

  # Helper for formatting cards
  defp format_card(%{rank: rank, suit: suit}) do
    suit_symbol =
      case suit do
        "hearts" -> "♥"
        "diamonds" -> "♦"
        "clubs" -> "♣"
        "spades" -> "♠"
      end

    "#{rank}#{suit_symbol}"
  end

  defp format_card(card) when is_binary(card), do: card

  # Helper to get suit color class
  defp suit_color(%{suit: suit}) do
    case suit do
      "hearts" -> "text-red-600"
      "diamonds" -> "text-red-600"
      "clubs" -> "text-gray-900"
      "spades" -> "text-gray-900"
    end
  end

  # Get seat position styling for oval table layout
  # Current player is always at bottom center, others arranged by position
  defp seat_position(participant, current_user_id, participants) do
    if participant.player_id == current_user_id do
      # Current player always at bottom center
      "bottom-[-16%] left-1/2 -translate-x-1/2"
    else
      # Position other players around the table based on their position
      position_index(participant, current_user_id, participants)
    end
  end

  # Calculate position around table for non-current players
  defp position_index(participant, current_user_id, participants) do
    # Find current player and this participant in the list
    current_idx = Enum.find_index(participants, &(&1.player_id == current_user_id)) || 0
    participant_idx = Enum.find_index(participants, &(&1.id == participant.id)) || 0

    # Calculate relative position (clockwise from current player)
    relative_pos = rem(participant_idx - current_idx + length(participants), length(participants))

    # Map relative positions to CSS classes (6-max table)
    case relative_pos do
      # Right of hero
      1 -> "bottom-0 right-[10%]"
      # Middle right
      2 -> "top-1/2 right-[-14%] -translate-y-1/2"
      # Top right
      3 -> "top-24 right-12"
      # Top left
      4 -> "top-24 left-12"
      # Middle left
      5 -> "top-1/2 left-4 -translate-y-1/2"
      # Left of hero
      _ -> "bottom-24 left-12"
    end
  end

  def normalized_table_type(:six_max), do: "6-max"
end
