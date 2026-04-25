defmodule PokerWeb.PlayerLive.TournamentLobby do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tournaments
  alias Poker.Tournaments.BlindStructure

  @impl true
  def mount(%{"id" => tournament_id}, _session, socket) do
    case Tournaments.get_tournament(tournament_id) do
      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Tournament not found")
         |> push_navigate(to: ~p"/")}

      {:ok, tournament} ->
        table = Poker.Tournaments.Queries.table_by_source(tournament_id)

        if connected?(socket) do
          Poker.Tournaments.PubSub.subscribe_to_tournament(tournament_id)

          if table do
            Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table.id}:lobby")
          end
        end

        {:ok,
         assign(socket,
           tournament: tournament,
           tournament_id: tournament_id,
           table: table,
           lobby: table && Poker.Tables.get_lobby(table.id),
           user_id: socket.assigns.current_scope.user.id,
           blind_levels: BlindStructure.levels_for(tournament.speed),
           registered_players: find_registered_players(tournament.player_ids)
         )}
    end
  end

  @impl true
  def handle_event("register", _params, socket) do
    case Tournaments.register_player(socket.assigns.current_scope, socket.assigns.tournament_id) do
      :ok ->
        {:ok, tournament} = Tournaments.get_tournament(socket.assigns.tournament_id)
        {:noreply, assign(socket, tournament: tournament)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  @impl true
  def handle_info({:table_lobby, :table_started, %{table_id: table_id}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/game")}
  end

  def handle_info({:table_lobby, _event, _data}, socket) do
    table = Poker.Tournaments.Queries.table_by_source(socket.assigns.tournament_id)

    if table do
      lobby = Poker.Tables.get_lobby(table.id)
      {:noreply, assign(socket, table: table, lobby: lobby)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:tournament, :tournament_started, %{tournament_id: tournament_id}}, socket) do
    table = Poker.Tournaments.Queries.table_by_source(tournament_id)

    if table do
      {:noreply, push_navigate(socket, to: ~p"/tables/#{table.id}/game")}
    else
      {:ok, tournament} = Tournaments.get_tournament(tournament_id)

      {:noreply,
       assign(socket,
         tournament: tournament,
         registered_players: find_registered_players(tournament.player_ids)
       )}
    end
  end

  def handle_info({:tournament, _event, _data}, socket) do
    {:ok, tournament} = Tournaments.get_tournament(socket.assigns.tournament_id)

    {:noreply,
     assign(socket,
       tournament: tournament,
       registered_players: find_registered_players(tournament.player_ids)
     )}
  end

  defp find_registered_players(player_ids) do
    Enum.map(player_ids || [], fn player_id ->
      Poker.Accounts.get_user!(player_id)
    end)
  end

  defp format_error(:already_registered), do: "You are already registered"
  defp format_error(:tournament_full), do: "Tournament is full"
  defp format_error(:registration_closed), do: "Registration is closed"
  defp format_error(:insufficient_balance), do: "Insufficient wallet balance"
  defp format_error(%{message: message}), do: message
  defp format_error(reason) when is_atom(reason), do: "Registration failed: #{reason}"
  defp format_error(reason), do: "Registration failed: #{inspect(reason)}"

  defp format_speed(:regular), do: "Regular"
  defp format_speed(:turbo), do: "Turbo"
  defp format_speed(:hyper_turbo), do: "Hyper-Turbo"

  defp level_duration(:regular), do: "10 min"
  defp level_duration(:turbo), do: "5 min"
  defp level_duration(:hyper_turbo), do: "3 min"

  @impl true
  def render(assigns) do
    ~H"""
    <.flash kind={:error} flash={@flash} />
    <.flash kind={:info} flash={@flash} />

    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6">
          <.link
            navigate={~p"/"}
            class="inline-flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 transition-colors group"
          >
            <svg
              class="w-4 h-4 group-hover:-translate-x-1 transition-transform"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Back to Lobby
          </.link>
        </div>

        <div class="mb-8">
          <h1 class="text-4xl font-bold text-slate-900 dark:text-white mb-2">
            Sit & Go - {format_speed(@tournament.speed)}
          </h1>
          <p class="text-slate-600 dark:text-slate-400">
            <%= case @tournament.status do %>
              <% :registering -> %>
                Waiting for players to register ({@tournament.registered_count}/{@tournament.max_players})
              <% :active -> %>
                Tournament in progress
              <% :finished -> %>
                Tournament finished
            <% end %>
          </p>
        </div>

        <div class="grid lg:grid-cols-3 gap-6">
          <!-- Tournament Info -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Info Card -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
              <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700 bg-gradient-to-r from-amber-500 to-orange-500">
                <div class="flex items-center justify-between">
                  <h2 class="text-xl font-semibold text-white">Tournament Info</h2>
                  <span class={"px-3 py-1 rounded-full text-sm font-medium #{
                    case @tournament.status do
                      :active -> "bg-white/20 text-white border border-white/30"
                      :registering -> "bg-amber-700/30 text-white border border-amber-300/30"
                      :finished -> "bg-red-500/30 text-white border border-red-300/30"
                    end
                  }"}>
                    {String.capitalize(to_string(@tournament.status))}
                  </span>
                </div>
              </div>

              <div class="p-6">
                <div class="grid grid-cols-2 md:grid-cols-3 gap-6">
                  <div class="space-y-1">
                    <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Buy-in</p>
                    <p class="text-lg font-semibold text-slate-900 dark:text-white">{@tournament.buy_in}</p>
                  </div>
                  <div class="space-y-1">
                    <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Starting Stack</p>
                    <p class="text-lg font-semibold text-slate-900 dark:text-white">{@tournament.starting_stack}</p>
                  </div>
                  <div class="space-y-1">
                    <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Speed</p>
                    <p class="text-lg font-semibold text-slate-900 dark:text-white">{format_speed(@tournament.speed)}</p>
                  </div>
                  <div class="space-y-1">
                    <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Level Duration</p>
                    <p class="text-lg font-semibold text-slate-900 dark:text-white">{level_duration(@tournament.speed)}</p>
                  </div>
                  <div class="space-y-1">
                    <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Players</p>
                    <p class="text-lg font-semibold text-slate-900 dark:text-white">
                      {@tournament.registered_count}<span class="text-slate-400">/{@tournament.max_players}</span>
                    </p>
                  </div>
                  <div class="space-y-1">
                    <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Prize Pool</p>
                    <p class="text-lg font-semibold text-amber-600 dark:text-amber-400">
                      {(@tournament.buy_in || 0) * (@tournament.registered_count || 0)}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Blind Structure -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
              <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white">Blind Structure</h2>
              </div>
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                      <th class="px-6 py-3">Level</th>
                      <th class="px-6 py-3">Small Blind</th>
                      <th class="px-6 py-3">Big Blind</th>
                      <th class="px-6 py-3">Duration</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-200 dark:divide-slate-700">
                    <%= for level <- @blind_levels do %>
                      <tr class={"#{if level.level == @tournament.current_level, do: "bg-amber-50 dark:bg-amber-900/10", else: ""}"}>
                        <td class="px-6 py-2 text-sm font-medium text-slate-900 dark:text-white">
                          {level.level}
                          <%= if level.level == @tournament.current_level and @tournament.status == :active do %>
                            <span class="ml-2 text-amber-600 dark:text-amber-400 text-xs font-bold">CURRENT</span>
                          <% end %>
                        </td>
                        <td class="px-6 py-2 text-sm text-slate-600 dark:text-slate-400">{level.small_blind}</td>
                        <td class="px-6 py-2 text-sm text-slate-600 dark:text-slate-400">{level.big_blind}</td>
                        <td class="px-6 py-2 text-sm text-slate-600 dark:text-slate-400">{div(level.duration_seconds, 60)} min</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <!-- Sidebar: Players + Actions -->
          <div class="space-y-6">
            <!-- Registered Players -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
              <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white">
                  Players <span class="text-slate-400">({@tournament.registered_count}/{@tournament.max_players})</span>
                </h2>
              </div>

              <div class="p-4">
                <%= if Enum.empty?(@registered_players) do %>
                  <p class="text-sm text-slate-500 dark:text-slate-400 text-center py-4">
                    No players registered yet
                  </p>
                <% else %>
                  <div class="space-y-2">
                    <%= for player <- @registered_players do %>
                      <div class="flex items-center gap-3 px-3 py-2 rounded-lg bg-slate-50 dark:bg-slate-750">
                        <div class="w-8 h-8 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center text-white font-semibold text-xs">
                          {String.first(player.email) |> String.upcase()}
                        </div>
                        <span class="text-sm font-medium text-slate-700 dark:text-slate-300 truncate">
                          {player.email}
                        </span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Action Button -->
            <%= if @tournament.status == :registering do %>
              <button
                phx-click="register"
                class="w-full bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white font-semibold py-3 px-4 rounded-xl shadow-md hover:shadow-lg transition-all duration-200"
              >
                <span class="flex items-center justify-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                  </svg>
                  Register - Buy-in {@tournament.buy_in}
                </span>
              </button>
            <% end %>

            <%= if @tournament.status == :active && @table do %>
              <.link
                navigate={~p"/tables/#{@table.id}/game"}
                class="block w-full text-center bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 px-4 rounded-xl shadow-md hover:shadow-lg transition-all duration-200"
              >
                <span class="flex items-center justify-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <%= if @user_id in (@tournament.player_ids || []) do %>
                    Enter Table
                  <% else %>
                    Watch Game
                  <% end %>
                </span>
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
