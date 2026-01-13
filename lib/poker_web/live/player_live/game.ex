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
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
      end

      game_view =
        Tables.get_player_game_view(socket.assigns.current_scope, table_id)

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

    socket = assign(socket, queue: remaining_queue)
    socket = process_next_event(socket)

    {:noreply, socket}
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

        socket = push_event(socket, "table_events", %{events: serialize_events([next_event])})

        assign(socket,
          current_animated_event_id: next_event.event_id,
          game_view: game_view,
          raise_amount: nil
        )
    end
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
    <div id="game-container" phx-hook="TableEvents" class="min-h-screen bg-green-800 p-8">
      <div class="max-w-7xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/"} class="text-white hover:text-gray-200">
            &larr; Back to Lobby
          </.link>
        </div>

        <%= if @game_view.hand_id do %>
          <!-- Active Hand -->
            <!-- Poker Table Container -->
          <div class="relative w-full h-[600px] mb-32 flex items-center justify-center">
            <!-- Oval Table -->
            <div class="relative max-h-[500px] max-w-[800px] w-[100%] h-[100%] bg-green-700 rounded-[50%] border-8 border-amber-900 shadow-2xl">
              <h1 class="text-2xl font-bold text-white mb-6 text-center absolute top-[52%] left-1/2 -translate-x-1/2 z-1 opacity-[0.3] text-md">
                Poker Table | NL - Holdem | {normalized_table_type(@lobby.table_type)}

                <%= if @game_view.table_status == :finished do %>
                  | Finished
                <% end %>
              </h1>
              
    <!-- Community Cards in center -->
              <div class="community-cards-area flex justify-center mt-[15%] gap-2 h-20">
                <%= if !Enum.empty?(@game_view.community_cards) do %>
                  <%= for card <- @game_view.community_cards do %>
                    <div class={[
                      "community-card bg-white rounded p-2 w-16 h-20 flex items-center justify-center font-bold text-xl shadow-lg",
                      suit_color(card)
                    ]}>
                      {format_card(card)}
                    </div>
                  <% end %>
                <% end %>
              </div>
              <div class="pot-area text-center flex flex-row items-center gap-2 justify-center mt-3">
                <%= if @game_view.hand_status != :finished && @game_view.total_pot > 0 do %>
                  <p class="text-yellow-300 text-sm font-semibold total-pot-amount">
                    $<span class="inline total-pot">{@game_view.total_pot}</span>
                  </p>
                  <div data-pot-area>
                    <.chip_stack amount={@game_view.total_pot} size={:small} class="pot-chips" />
                  </div>
                <% end %>
              </div>

              <%= for participant <- @game_view.participants do %>
                <% lobby_participant =
                  Enum.find(@lobby.participants, &(&1.player_id == participant.player_id)) %>

                <div
                  class={[
                    "absolute flex flex-col items-center z-2",
                    seat_position(participant, @current_user_id, @game_view.participants)
                  ]}
                  data-participant-id={participant.id}
                >
                  <div data-cards-area>
                    <!-- Cards at top (bigger) - will overlap player info -->
                    <%= if participant.player_id == @current_user_id && !Enum.empty?(@game_view.hole_cards) do %>
                      <div class="flex gap-1 relative mb-[-19px]">
                        <%= for card <- @game_view.hole_cards do %>
                          <div class={[
                            "bg-white rounded shadow-lg p-2 w-16 h-20 flex items-center justify-center font-bold text-xl border-2 border-gray-200",
                            suit_color(card)
                          ]}>
                            {format_card(card)}
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <%= if !Enum.empty?(participant.showdown_cards) do %>
                        <div class="showdown-cards flex gap-1 relative mb-[-29px]">
                          <%= for card <- participant.showdown_cards do %>
                            <div class={[
                              "bg-white rounded shadow-lg p-2 w-16 h-20 flex items-center justify-center font-bold text-xl border-2 border-gray-200",
                              suit_color(card)
                            ]}>
                              {format_card(card)}
                            </div>
                          <% end %>
                        </div>
                      <% else %>
                        <%= if participant.received_hole_cards? do %>
                          <div class="flex gap-1 relative mb-[-29px]">
                            <div class="bg-blue-900 border-2 border-blue-700 rounded shadow-lg p-2 w-16 h-20 flex items-center justify-center">
                              <span class="text-blue-400 text-2xl">🂠</span>
                            </div>
                            <div class="bg-blue-900 border-2 border-blue-700 rounded shadow-lg p-2 w-16 h-20 flex items-center justify-center">
                              <span class="text-blue-400 text-2xl">🂠</span>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    <% end %>
                  </div>
                  
    <!-- Dealer Button Indicator -->
                  <%= if participant.position == :dealer do %>
                    <div class="dealer-button">
                      <div class="poker-chip">
                        <span>D</span>
                      </div>
                    </div>
                  <% end %>
                  
    <!-- Bet area with chips (positioned above player info) -->
                  <%= if participant.bet_this_round > 0 do %>
                    <div
                      class="bet-area absolute bottom-[160px] left-1/2 -translate-x-1/2 flex flex-col items-center gap-1 z-10"
                      data-bet-area
                      data-participant-id={participant.id}
                    >
                      <.chip_stack
                        amount={participant.bet_this_round}
                        size={:small}
                        class="bet-chips"
                      />
                      <span class="text-yellow-300 text-xs font-bold bet-amount">
                        ${participant.bet_this_round}
                      </span>
                    </div>
                  <% end %>
                  
    <!-- Compact player info below cards - overlapped by cards -->
                  <div class={[
                    "bg-gray-900/95 backdrop-blur rounded-2xl px-7 py-4 shadow-xl border border-gray-700 min-w-[140px] relative z-0",
                    if(participant.id == @game_view.current_participant_to_act_id,
                      do: "ring-2 ring-yellow-400"
                    )
                  ]}>
                    <div class="text-white text-center">
                      <!-- Name and status -->
                      <div class="flex items-center justify-center gap-2 mb-1 z-2">
                        <p class="font-semibold text-sm truncate max-w-[100px]">
                          {(lobby_participant && lobby_participant.email) || "Unknown"}
                        </p>
                        <%= if participant.hand_status == :folded do %>
                          <span class="text-xs px-1 py-0.5 rounded bg-red-600">F</span>
                        <% end %>
                        <%= if participant.hand_status == :all_in do %>
                          <span class="text-xs px-1 py-0.5 rounded bg-yellow-600">AI</span>
                        <% end %>
                      </div>
                      
    <!-- Chips -->
                      <p class="text-xs font-bold text-green-400">
                        ${participant.chips}
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
            
    <!-- Players positioned around table -->
          </div>
        <% end %>
        
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
