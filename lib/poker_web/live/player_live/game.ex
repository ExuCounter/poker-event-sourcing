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
        Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:game")
        Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:lobby")
      end

      table_state = Tables.get_table_state(socket.assigns.current_scope, table_id)

      {:ok,
       assign(socket,
         table_id: table_id,
         lobby: lobby,
         table_state: table_state
       )}
    end
  end

  @impl true
  def handle_info(:game_updated, socket) do
    table_state = Tables.get_table_state(socket.assigns.current_scope, socket.assigns.table_id)
    {:noreply, assign(socket, table_state: table_state)}
  end

  def handle_info(:lobby_updated, socket) do
    lobby = Tables.get_lobby(socket.assigns.table_id)
    {:noreply, assign(socket, lobby: lobby)}
  end

  @impl true
  def render(assigns) do
    ~H"""
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

          <%= if @table_state do %>
            <!-- Active Hand -->
            <div class="mb-8">
              <!-- Community Cards -->
              <div class="flex justify-center gap-2 mb-6">
                <h3 class="text-white font-semibold mr-4">Community Cards:</h3>
                <%= if Enum.empty?(@table_state.community_cards) do %>
                  <span class="text-gray-400">No cards yet</span>
                <% else %>
                  <%= for card <- @table_state.community_cards do %>
                    <div class="bg-white rounded p-2 w-16 h-20 flex items-center justify-center font-bold text-xl">
                      {card}
                    </div>
                  <% end %>
                <% end %>
              </div>
              
    <!-- Pots -->
              <div class="text-center mb-6">
                <h3 class="text-white font-semibold">Total Pot:</h3>
                <p class="text-yellow-400 text-2xl font-bold">
                  {Enum.sum(Enum.map(@table_state.pots, & &1.amount))}
                </p>
              </div>
              
    <!-- Round Type -->
              <%= if @table_state.round_type do %>
                <div class="text-center mb-6">
                  <span class="text-white bg-blue-600 px-4 py-2 rounded-full">
                    {String.upcase(to_string(@table_state.round_type))}
                  </span>
                </div>
              <% end %>
              
    <!-- Players Grid -->
              <div class="grid grid-cols-3 gap-4 mt-8">
                <%= for participant_hand <- @table_state.participant_hands do %>
                  <% participant =
                    Enum.find(@lobby.participants, &(&1.player_id == participant_hand.participant_id)) ||
                      %{
                        email: "Unknown"
                      } %>
                  <div class={[
                    "bg-gray-800 rounded-lg p-4",
                    if(
                      participant_hand.participant_id == @table_state.participant_to_act_id,
                      do: "ring-4 ring-yellow-400",
                      else: ""
                    )
                  ]}>
                    <div class="text-white">
                      <div class="flex justify-between items-center mb-2">
                        <p class="font-semibold">{participant.email}</p>
                        <span class={[
                          "text-xs px-2 py-1 rounded",
                          case participant_hand.status do
                            :active -> "bg-green-600"
                            :folded -> "bg-red-600"
                            :all_in -> "bg-yellow-600"
                          end
                        ]}>
                          {participant_hand.status}
                        </span>
                      </div>

                      <p class="text-sm text-gray-400">
                        Seat {participant_hand.seat_number} • {participant_hand.position}
                      </p>

                      <%= if !Enum.empty?(participant_hand.hole_cards) do %>
                        <div class="flex gap-1 mt-2">
                          <%= for card <- participant_hand.hole_cards do %>
                            <div class="bg-white rounded p-1 w-12 h-16 flex items-center justify-center font-bold text-sm">
                              {card}
                            </div>
                          <% end %>
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
                  <div class="bg-gray-800 rounded-lg p-4">
                    <div class="text-white">
                      <p class="font-semibold">{participant.email}</p>
                      <p class="text-sm text-gray-400">Ready to play</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          <div class="flex flex-end">
            <.button phx-click="fold_hand" class="bg-red-600 hover:bg-red-700">
              Fold
            </.button>
            <.button phx-click="all_in_hand" class="bg-blue-600 hover:bg-blue-700">
              Raise hand
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
