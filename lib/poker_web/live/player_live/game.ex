defmodule PokerWeb.PlayerLive.Game do
  use PokerWeb, :live_view

  import Ecto.Query
  import PokerWeb.PlayerLive.GameHelpers

  alias PokerWeb.Api.Tables
  alias Poker.Tables.Projections.{TableParticipants, TableRounds, TableParticipantHands}

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    lobby = Tables.get_lobby(table_id)

    if is_nil(lobby) do
      {:ok,
       socket
       |> put_flash(:error, "Table not found")
       |> push_navigate(to: ~p"/")}
    else
      current_user_id = socket.assigns.current_scope.user.id

      if connected?(socket) do
        # Subscribe to unified table channel
        Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
      end

      # Load initial table state using get_table
      table_data = Tables.get_table(table_id)

      # Find current user's participant
      current_participant =
        Enum.find(table_data.participants, &(&1.player_id == current_user_id))

      # Get current round (most recent)
      current_round =
        table_data.hand && List.last(table_data.hand.rounds)

      community_cards =
        table_data.hand &&
          Enum.flat_map(table_data.hand.rounds, fn round -> round.community_cards end)

      # Filter hole cards to hide other players' cards
      filtered_participant_hands =
        filter_hole_cards(
          (table_data.hand && table_data.hand.participant_hands) || [],
          current_user_id,
          table_data.participants
        )

      {:ok,
       assign(socket,
         table_id: table_id,
         current_user_id: current_user_id,
         lobby: lobby,
         table: table_data.table,
         participants: table_data.participants,
         hand: table_data.hand,
         current_round: current_round,
         participant_to_act_id: current_round && current_round.participant_to_act_id,
         current_participant_id: current_participant && current_participant.id,
         participant_hands: filtered_participant_hands,
         community_cards: community_cards || [],
         pots: (table_data.hand && table_data.hand.pots) || [],
         event_queue: [],
         raise_amount: nil
       )}
    end
  end

  # Handle unified table events
  @impl true
  def handle_info({:table, event, data}, socket) do
    socket = handle_table_event(event, data, socket)

    {:noreply, socket}
  end

  # Event dispatcher - use event data directly when possible
  defp handle_table_event(:participant_hand_given, participant_hand, socket) do
    participant =
      Enum.find(socket.assigns.participants, &(&1.id == participant_hand.participant_id))

    participant_hand =
      if participant && participant.player_id == socket.assigns.current_user_id do
        participant_hand
      else
        %{participant_hand | hole_cards: []}
      end

    assign(socket,
      participant_hands: socket.assigns.participant_hands ++ [participant_hand]
    )
  end

  # Event dispatcher - use event data directly when possible
  defp handle_table_event(:hand_started, %{hand_id: hand_id}, socket) do
    assign(socket,
      hand: %{
        id: hand_id,
        pots: [],
        status: :active
      }
    )
  end

  defp handle_table_event(
         :round_started,
         %{id: round_id, community_cards: round_community_cards},
         socket
       ) do
    assign(socket,
      current_round: %{
        id: round_id
      },
      community_cards: socket.assigns.community_cards ++ round_community_cards
    )
  end

  defp handle_table_event(:round_finished, _data, socket) do
    participant_hands = Enum.map(socket.assigns.participant_hands, &%{&1 | bet_this_round: 0})
    assign(socket, participant_hands: participant_hands, raise_amount: nil)
  end

  defp handle_table_event(:participant_to_act_selected, %{participant_id: participant_id}, socket) do
    assign(socket, participant_to_act_id: participant_id)
  end

  defp handle_table_event(
         :participant_raised,
         %{
           participant_id: participant_id,
           amount: amount
         },
         socket
       ) do
    participant_hands =
      Enum.map(socket.assigns.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          %{participant_hand | bet_this_round: participant_hand.bet_this_round + amount}

        participant_hand ->
          participant_hand
      end)

    participants =
      Enum.map(socket.assigns.participants, fn
        %{id: ^participant_id} = participant ->
          %{participant | chips: participant.chips - amount}

        participant ->
          participant
      end)

    assign(socket, participant_hands: participant_hands, participants: participants)
  end

  defp handle_table_event(:participant_checked, %{participant_id: _participant_id}, socket),
    do: socket

  defp handle_table_event(
         :small_blind_posted,
         %{
           participant_id: participant_id,
           amount: amount
         },
         socket
       ) do
    participant_hands =
      Enum.map(socket.assigns.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          %{participant_hand | bet_this_round: participant_hand.bet_this_round + amount}

        participant_hand ->
          participant_hand
      end)

    participants =
      Enum.map(socket.assigns.participants, fn
        %{id: ^participant_id} = participant ->
          %{participant | chips: participant.chips - amount}

        participant ->
          participant
      end)

    assign(socket, participant_hands: participant_hands, participants: participants)
  end

  defp handle_table_event(
         :big_blind_posted,
         %{
           participant_id: participant_id,
           amount: amount
         },
         socket
       ) do
    participant_hands =
      Enum.map(socket.assigns.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          %{participant_hand | bet_this_round: participant_hand.bet_this_round + amount}

        participant_hand ->
          participant_hand
      end)

    participants =
      Enum.map(socket.assigns.participants, fn
        %{id: ^participant_id} = participant ->
          %{participant | chips: participant.chips - amount}

        participant ->
          participant
      end)

    assign(socket, participant_hands: participant_hands, participants: participants)
  end

  defp handle_table_event(
         :participant_called,
         %{
           participant_id: participant_id,
           amount: amount
         },
         socket
       ) do
    participant_hands =
      Enum.map(socket.assigns.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          %{participant_hand | bet_this_round: participant_hand.bet_this_round + amount}

        participant_hand ->
          participant_hand
      end)

    participants =
      Enum.map(socket.assigns.participants, fn
        %{id: ^participant_id} = participant ->
          %{participant | chips: participant.chips - amount}

        participant ->
          participant
      end)

    assign(socket, participant_hands: participant_hands, participants: participants)
  end

  defp handle_table_event(
         :participant_went_all_in,
         %{
           participant_id: participant_id,
           amount: amount
         },
         socket
       ) do
    participant_hands =
      Enum.map(socket.assigns.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          %{participant_hand | bet_this_round: participant_hand.bet_this_round + amount}

        participant_hand ->
          participant_hand
      end)

    participants =
      Enum.map(socket.assigns.participants, fn
        %{id: ^participant_id} = participant ->
          %{participant | chips: participant.chips - amount}

        participant ->
          participant
      end)

    assign(socket, participant_hands: participant_hands, participants: participants)
  end

  defp handle_table_event(
         :participant_folded,
         %{participant_id: participant_id, status: status},
         socket
       ) do
    participant_hands =
      Enum.map(socket.assigns.participant_hands, fn
        %{participant_id: ^participant_id} = participant_hand ->
          %{participant_hand | status: status}

        participant_hand ->
          participant_hand
      end)

    assign(socket, participant_hands: participant_hands)
  end

  defp handle_table_event(:pots_updated, %{pots: pots}, socket) do
    assign(socket, pots: pots)
  end

  defp handle_table_event(:hand_finished, %{payouts: payouts}, socket) do
    participants =
      Enum.map(socket.assigns.participants, fn participant ->
        amount =
          payouts
          |> Enum.filter(&(&1.participant_id == participant.id))
          |> Enum.reduce(0, fn payout, acc -> acc + payout.amount end)

        %{participant | chips: participant.chips + amount}
      end)

    assign(socket,
      participants: participants,
      hand: nil,
      current_round: nil,
      participant_to_act_id: nil,
      participant_hands: [],
      community_cards: [],
      raise_amount: nil
    )
  end

  defp handle_table_event(_event, _data, socket), do: socket

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
    # Calculate action state for button rendering
    assigns = assign(assigns, :action_state, calculate_action_state(assigns))

    # Calculate raise limits
    {min_raise, max_raise} =
      calculate_raise_limits(assigns.action_state, assigns.lobby.small_blind)

    assigns = assign(assigns, min_raise: min_raise, max_raise: max_raise)

    # Initialize raise_amount if not set
    assigns =
      if is_nil(assigns.raise_amount) do
        assign(assigns, raise_amount: min_raise)
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

          <%= if @hand && @hand.status == :active do %>
            <!-- Active Hand -->
            <div class="mb-8">
              <!-- Community Cards -->
              <div class="flex justify-center gap-2 mb-6">
                <%= if @current_round && !Enum.empty?(@community_cards) do %>
                  <%= for card <- @community_cards do %>
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
                  {@action_state.pot_size}
                </p>
              </div>
              
    <!-- Players Grid -->
              <div class="grid grid-cols-3 gap-4 mt-8 mb-24">
                <%= for participant_hand <- @participant_hands do %>
                  <% participant_info = get_participant_info(participant_hand, @participants, @lobby) %>

                  <div class={[
                    "bg-gray-800 rounded-lg p-4",
                    if(participant_hand.participant_id == @participant_to_act_id,
                      do: "ring-4 ring-yellow-400 animate-pulse"
                    )
                  ]}>
                    <div class="text-white">
                      <div class="flex justify-between items-center mb-2">
                        <p class="font-semibold">{participant_info.email}</p>
                        <span class={[
                          "text-xs px-2 py-1 rounded",
                          case participant_info.hand_status do
                            :playing -> "bg-green-600"
                            :folded -> "bg-red-600"
                            :all_in -> "bg-yellow-600"
                            _ -> "bg-gray-600"
                          end
                        ]}>
                          {participant_info.hand_status}
                        </span>
                      </div>

                      <p class="text-sm text-gray-400 mb-1">
                        {participant_info.position}
                      </p>

                      <div class="flex justify-between items-center mb-2">
                        <p class="text-lg font-bold text-green-400">
                          {participant_info.chips} chips
                        </p>

                        <%= if participant_hand.bet_this_round > 0 do %>
                          <div class="bg-yellow-500 text-gray-900 px-2 py-1 rounded-md font-bold text-sm">
                            Bet: {participant_hand.bet_this_round}
                          </div>
                        <% end %>
                      </div>

    <!-- Hole Cards -->
                      <%= if !Enum.empty?(participant_info.hole_cards) do %>
                        <div class="flex gap-1 mt-2">
                          <%= for card <- participant_info.hole_cards do %>
                            <div class={[
                              "bg-white rounded p-1 w-14 h-18 flex items-center justify-center font-bold text-md",
                              suit_color(card)
                            ]}>
                              {format_card(card)}
                            </div>
                          <% end %>
                        </div>
                      <% else %>
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
                <%= for participant <- @lobby.participants do %>
                  <% participant_data =
                    Enum.find(@participants, &(&1.player_id == participant.player_id)) %>
                  <div class="bg-gray-800 rounded-lg p-4">
                    <div class="text-white">
                      <p class="font-semibold">{participant.email}</p>
                      <%= if participant_data do %>
                        <p class="text-lg font-bold text-green-400">{participant_data.chips} chips</p>
                      <% else %>
                        <p class="text-sm text-gray-400">Ready to play</p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
    <!-- Action Controls - Fixed to bottom -->
          <%= if @hand && @hand.status == :active do %>
            <div class="fixed bottom-8 right-7 bg-gray-900 rounded-2xl p-6 shadow-2xl border-2 border-gray-700">
              <%= if @action_state.is_my_turn do %>
                <div class="flex gap-4 items-center">
                  <!-- Fold Button -->
                  <.button
                    phx-click="fold_hand"
                    class="bg-red-600 hover:bg-red-700 text-white font-bold px-6 py-3 rounded-lg"
                  >
                    Fold
                  </.button>
                  
    <!-- Check Button (only when no bet) -->
                  <%= if @action_state.can_check do %>
                    <.button
                      phx-click="check_hand"
                      class="bg-blue-600 hover:bg-blue-700 text-white font-bold px-6 py-3 rounded-lg"
                    >
                      Check
                    </.button>
                  <% end %>
                  
    <!-- Call Button (only when there's a bet) -->
                  <%= if @action_state.can_call do %>
                    <.button
                      phx-click="call_hand"
                      class="bg-green-600 hover:bg-green-700 text-white font-bold px-6 py-3 rounded-lg"
                    >
                      Call {@action_state.call_amount}
                    </.button>
                  <% end %>
                  
    <!-- Raise Controls -->
                  <%= if @action_state.can_raise do %>
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
                              min={@min_raise}
                              max={@max_raise}
                              value={@raise_amount}
                              phx-change="update_raise_amount"
                              class="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-yellow-500"
                            />
                          </form>
                          <div class="flex justify-between text-xs text-gray-500">
                            <span>{@min_raise}</span>
                            <span>{@max_raise}</span>
                          </div>
                        </div>
                        <!-- Quick Presets -->
                        <div class="flex gap-2 flex-wrap pt-4">
                          <%= for {label, amount} <- calculate_raise_presets(@action_state) do %>
                            <button
                              type="button"
                              phx-click="update_raise_amount"
                              phx-value-raise_amount={amount}
                              class="bg-gray-700 hover:bg-gray-600 text-gray-300 text-xs px-2 py-1 rounded"
                            >
                              {label}
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
                <!-- Info Display 
                <div class="mt-4 flex gap-6 text-sm text-gray-400 justify-center">
                  <span>
                    Pot: <span class="text-yellow-400 font-bold">{@action_state.pot_size}</span>
                  </span>
                  <span>
                    Your Chips: <span class="text-green-400 font-bold">{@action_state.my_chips}</span>
                  </span>
                  <%= if @action_state.current_bet > 0 do %>
                    <span>
                      Current Bet:
                      <span class="text-red-400 font-bold">{@action_state.current_bet}</span>
                    </span>
                  <% end %>
                </div>
    -->
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
