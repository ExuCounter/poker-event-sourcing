defmodule PokerWeb.PlayerLive.Game do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

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
        # Subscribe to unified table channel
        Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
      end

      # Load complete player view (all calculations done server-side)
      game_view =
        Tables.get_player_game_view(socket.assigns.current_scope, table_id, 0)

      {:ok,
       assign(socket,
         table_id: table_id,
         lobby: lobby,
         game_view: game_view,
         current_user_id: socket.assigns.current_scope.user.id,
         raise_amount: nil
       )}
    end
  end

  # Handle unified table events
  @impl true
  def handle_info({:table, _event, _data}, socket) do
    # Simply rebuild the view from events (events are already in event store)
    game_view =
      Tables.get_player_game_view(
        socket.assigns.current_scope,
        socket.assigns.table_id,
        socket.assigns.game_view.latest_event_number
      )

    # Reset raise amount when round changes
    {:noreply, assign(socket, game_view: game_view, raise_amount: nil)}
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
    <div class="min-h-screen bg-green-800 p-8">
      <div class="max-w-7xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/"} class="text-white hover:text-gray-200">
            &larr; Back to Lobby
          </.link>
        </div>

        <div class="bg-green-900 rounded-3xl p-8 shadow-2xl">
          <h1 class="text-2xl font-bold text-white mb-6 text-center">
            Poker Table - {@lobby.table_type}
          </h1>

          <%= if @game_view.hand_id do %>
            <!-- Active Hand -->
            <div class="mb-8">
              <!-- Community Cards -->
              <div class="flex justify-center gap-2 mb-6">
                <%= if !Enum.empty?(@game_view.community_cards) do %>
                  <%= for card <- @game_view.community_cards do %>
                    <div class={[
                      "bg-white rounded p-2 w-20 h-24 flex items-center justify-center font-bold text-2xl",
                      suit_color(card)
                    ]}>
                      {format_card(card)}
                    </div>
                  <% end %>
                <% else %>
                  <span class="text-gray-400">No cards yet</span>
                <% end %>
              </div>
              
    <!-- Pots -->
              <div class="text-center mb-6">
                <h3 class="text-white font-semibold">Total Pot:</h3>
                <p class="text-yellow-400 text-2xl font-bold">
                  {@game_view.total_pot}
                </p>
              </div>
              
    <!-- Players Grid -->
              <div class="grid grid-cols-3 gap-4 mt-8 mb-24">
                <%= for participant <- @game_view.participants do %>
                  <% lobby_participant =
                    Enum.find(@lobby.participants, &(&1.player_id == participant.player_id)) %>

                  <div class={[
                    "bg-gray-800 rounded-lg p-4",
                    if(participant.id == @game_view.current_participant_to_act_id,
                      do: "ring-4 ring-yellow-400 animate-pulse"
                    )
                  ]}>
                    <div class="text-white">
                      <div class="flex justify-between items-center mb-2">
                        <p class="font-semibold">
                          {(lobby_participant && lobby_participant.email) || "Unknown"}
                        </p>
                        <%= if participant.hand_status do %>
                          <span class={[
                            "text-xs px-2 py-1 rounded",
                            case participant.hand_status do
                              :playing -> "bg-green-600"
                              :folded -> "bg-red-600"
                              :all_in -> "bg-yellow-600"
                              _ -> "bg-gray-600"
                            end
                          ]}>
                            {participant.hand_status}
                          </span>
                        <% end %>
                      </div>

                      <%= if participant.position do %>
                        <p class="text-sm text-gray-400 mb-1">
                          {participant.position}
                        </p>
                      <% end %>

                      <div class="flex justify-between items-center mb-2">
                        <p class="text-lg font-bold text-green-400">
                          {participant.chips} chips
                        </p>

                        <%= if participant.bet_this_round > 0 do %>
                          <div class="bg-yellow-500 text-gray-900 px-2 py-1 rounded-md font-bold text-sm">
                            Bet: {participant.bet_this_round}
                          </div>
                        <% end %>
                      </div>
                      
    <!-- Hole Cards - only show for current player -->
                      <%= if participant.player_id == @current_user_id && !Enum.empty?(@game_view.hole_cards) do %>
                        <div class="flex gap-1 mt-2">
                          <%= for card <- @game_view.hole_cards do %>
                            <div class={[
                              "bg-white rounded p-1 w-14 h-18 flex items-center justify-center font-bold text-md",
                              suit_color(card)
                            ]}>
                              {format_card(card)}
                            </div>
                          <% end %>
                        </div>
                      <% else %>
                        <%= if participant.hand_status do %>
                          <!-- Card backs for other players -->
                          <div class="flex gap-1 mt-2">
                            <div class="bg-blue-900 border-2 border-blue-700 rounded p-1 w-12 h-16 flex items-center justify-center">
                              <span class="text-blue-400 text-xs">🂠</span>
                            </div>
                            <div class="bg-blue-900 border-2 border-blue-700 rounded p-1 w-12 h-16 flex items-center justify-center">
                              <span class="text-blue-400 text-xs">🂠</span>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <!-- No Active Hand -->
            <div class="text-center text-white">
              <h2 class="text-xl mb-4">Waiting for hand to start...</h2>

              <div class="grid grid-cols-3 gap-4 mt-8">
                <%= for participant <- @game_view.participants do %>
                  <% lobby_participant =
                    Enum.find(@lobby.participants, &(&1.player_id == participant.player_id)) %>
                  <div class="bg-gray-800 rounded-lg p-4">
                    <div class="text-white">
                      <p class="font-semibold">
                        {(lobby_participant && lobby_participant.email) || "Unknown"}
                      </p>
                      <p class="text-lg font-bold text-green-400">{participant.chips} chips</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
    <!-- Action Controls - Fixed to bottom -->
          <%= if @game_view.hand_id do %>
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

    rank_str =
      case rank do
        "A" -> "A"
        "K" -> "K"
        "Q" -> "Q"
        "J" -> "J"
        "T" -> "10"
        n when is_integer(n) -> to_string(n)
        _ -> to_string(rank)
      end

    "#{rank_str}#{suit_symbol}"
  end

  defp format_card(card) when is_binary(card), do: card
  defp format_card(_), do: "?"

  # Helper to get suit color class
  defp suit_color(%{suit: suit}) do
    case suit do
      "hearts" -> "text-red-600"
      "diamonds" -> "text-red-600"
      "clubs" -> "text-gray-900"
      "spades" -> "text-gray-900"
    end
  end
end
