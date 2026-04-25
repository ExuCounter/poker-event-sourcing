defmodule PokerWeb.PlayerLive.Dashboard do
  use PokerWeb, :live_view

  alias PokerWeb.Api.CashGames
  alias PokerWeb.Api.Tournaments

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Poker.Tables.PubSub.subscribe_to_table_list()
      Poker.Tournaments.PubSub.subscribe_to_tournament_list()
    end

    {:ok,
     assign(socket,
       cash_games_list: CashGames.list_cash_games(),
       tournaments_list: Tournaments.list_tournaments(),
       form: to_form(%{}),
       balance: get_balance(socket.assigns.current_scope.user.id)
     )}
  end

  @impl true
  def handle_info({:table_list, _event, _data}, socket) do
    {:noreply, assign(socket, cash_games_list: CashGames.list_cash_games())}
  end

  @impl true
  def handle_info({:tournament_list, _event, _data}, socket) do
    {:noreply, assign(socket, tournaments_list: Tournaments.list_tournaments())}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    active_tab =
      case socket.assigns.live_action do
        :tournaments -> :tournaments
        _ -> :cash_games
      end

    {:noreply, assign(socket, active_tab: active_tab)}
  end

  @impl true
  def handle_event("create_cash_game", %{"cash_game" => params}, socket) do
    with {:ok, small_blind} <- parse_integer(params["small_blind"], "small blind"),
         {:ok, big_blind} <- parse_integer(params["big_blind"], "big blind"),
         {:ok, min_buyin} <- parse_integer(params["min_buyin"], "min buy-in"),
         {:ok, max_buyin} <- parse_integer(params["max_buyin"], "max buy-in"),
         {:ok, table_type} <- parse_table_type(params["table_type"]),
         :ok <- validate_buyins(min_buyin, max_buyin) do
      settings = %{
        small_blind: small_blind,
        big_blind: big_blind,
        min_buyin: min_buyin,
        max_buyin: max_buyin,
        table_type: table_type
      }

      case CashGames.create_cash_game(socket.assigns.current_scope, settings) do
        {:ok, %{table_id: table_id}} ->
          {:noreply, push_navigate(socket, to: ~p"/cash/#{table_id}/lobby")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create cash game: #{inspect(reason)}")}
      end
    else
      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("create_tournament", %{"tournament" => params}, socket) do
    with {:ok, buy_in} <- parse_integer(params["buy_in"], "buy-in"),
         {:ok, speed} <- parse_speed(params["speed"]),
         {:ok, table_type} <- parse_table_type(params["table_type"]) do
      settings = %{
        buy_in: buy_in,
        speed: speed,
        table_type: table_type
      }

      case Tournaments.create_tournament(socket.assigns.current_scope, settings) do
        {:ok, %{tournament_id: tournament_id}} ->
          {:noreply, push_navigate(socket, to: ~p"/tournaments/#{tournament_id}/lobby")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create tournament: #{inspect(reason)}")}
      end
    else
      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp parse_integer(value, field_name) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> {:ok, int}
      {_, _} -> {:error, "#{field_name} must be a positive number"}
      :error -> {:error, "Invalid #{field_name}"}
    end
  end

  defp parse_integer(_, field_name), do: {:error, "Invalid #{field_name}"}

  defp parse_table_type("two_max"), do: {:ok, :two_max}
  defp parse_table_type("three_max"), do: {:ok, :three_max}
  defp parse_table_type("four_max"), do: {:ok, :four_max}
  defp parse_table_type("six_max"), do: {:ok, :six_max}
  defp parse_table_type(_), do: {:error, "Invalid table type"}

  defp parse_speed("regular"), do: {:ok, :regular}
  defp parse_speed("turbo"), do: {:ok, :turbo}
  defp parse_speed("hyper_turbo"), do: {:ok, :hyper_turbo}
  defp parse_speed(_), do: {:error, "Invalid speed"}

  defp format_speed(:regular), do: "Regular"
  defp format_speed(:turbo), do: "Turbo"
  defp format_speed(:hyper_turbo), do: "Hyper-Turbo"

  defp get_balance(user_id) do
    case Poker.Wallet.get_wallet(user_id) do
      {:ok, wallet} -> wallet.balance
      {:error, _} -> 0
    end
  end

  defp validate_buyins(min, max) when min <= max, do: :ok
  defp validate_buyins(_, _), do: {:error, "Min buy-in must be less than or equal to max buy-in"}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-4xl font-bold text-slate-900 dark:text-white mb-2">Poker Lobby</h1>
            <p class="text-slate-600 dark:text-slate-400">Join a game or create your own</p>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 px-6 py-4">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Balance</p>
            <p class="text-2xl font-bold text-emerald-600 dark:text-emerald-400">${@balance}</p>
          </div>
        </div>

        <!-- Tabs -->
        <div class="mb-6">
          <div class="border-b border-slate-200 dark:border-slate-700">
            <nav class="-mb-px flex space-x-8">
              <.link
                patch={~p"/cash"}
                class={"py-4 px-1 border-b-2 font-medium text-sm transition-colors #{
                  if @active_tab == :cash_games do
                    "border-emerald-500 text-emerald-600 dark:text-emerald-400"
                  else
                    "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300 dark:text-slate-400 dark:hover:text-slate-300"
                  end
                }"}
              >
                <span class="flex items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Cash Games
                </span>
              </.link>
              <.link
                patch={~p"/tournaments"}
                class={"py-4 px-1 border-b-2 font-medium text-sm transition-colors #{
                  if @active_tab == :tournaments do
                    "border-emerald-500 text-emerald-600 dark:text-emerald-400"
                  else
                    "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300 dark:text-slate-400 dark:hover:text-slate-300"
                  end
                }"}
              >
                <span class="flex items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"
                    />
                  </svg>
                  Tournaments
                </span>
              </.link>
            </nav>
          </div>
        </div>

        <div class="grid lg:grid-cols-3 gap-8">
          <!-- Games List -->
          <div class="lg:col-span-2">
            <%= if @active_tab == :cash_games do %>
              <.cash_games_list cash_games={@cash_games_list} />
            <% else %>
              <.tournaments_list tournaments={@tournaments_list} />
            <% end %>
          </div>

          <!-- Create Form -->
          <div class="lg:col-span-1">
            <%= if @active_tab == :cash_games do %>
              <.create_cash_game_form form={@form} />
            <% else %>
              <.create_tournament_form form={@form} />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp cash_games_list(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
        <h2 class="text-xl font-semibold text-slate-900 dark:text-white">Active Cash Games</h2>
      </div>

      <div class="divide-y divide-slate-200 dark:divide-slate-700">
        <%= if Enum.empty?(@cash_games) do %>
          <div class="px-6 py-12 text-center">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-700 mb-4">
              <svg
                class="w-8 h-8 text-slate-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
            <p class="text-slate-500 dark:text-slate-400 font-medium">No active cash games</p>
            <p class="text-sm text-slate-400 dark:text-slate-500 mt-1">
              Create a new cash game to get started
            </p>
          </div>
        <% else %>
          <%= for cash_game <- @cash_games do %>
            <.link
              navigate={~p"/cash/#{cash_game.table_id}/lobby"}
              class="block px-6 py-4 hover:bg-slate-50 dark:hover:bg-slate-750 transition-colors duration-150 group"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-2">
                    <h3 class="text-lg font-semibold text-slate-900 dark:text-white group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                      No-Limit Hold'em
                    </h3>
                    <span class={"px-2.5 py-0.5 rounded-full text-xs font-medium #{
                      case cash_game.table_status do
                        :live -> "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
                        :waiting -> "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
                        :paused -> "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-400"
                        :finished -> "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
                        _ -> "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-400"
                      end
                    }"}>
                      {String.capitalize(to_string(cash_game.table_status))}
                    </span>
                  </div>
                  <div class="flex items-center gap-4 text-sm text-slate-600 dark:text-slate-400">
                    <div class="flex items-center gap-1.5">
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                      <span class="font-medium">
                        {cash_game.small_blind}/{cash_game.big_blind}
                      </span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"
                        />
                      </svg>
                      <span>Buy-in: {cash_game.min_buyin} - {cash_game.max_buyin}</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
                        />
                      </svg>
                      <span>6-Max</span>
                    </div>
                  </div>
                </div>
                <div class="ml-4 flex items-center">
                  <svg
                    class="w-5 h-5 text-slate-400 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </div>
            </.link>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp tournaments_list(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
        <h2 class="text-xl font-semibold text-slate-900 dark:text-white">Tournaments</h2>
      </div>

      <div class="divide-y divide-slate-200 dark:divide-slate-700">
        <%= if Enum.empty?(@tournaments) do %>
          <div class="px-6 py-12 text-center">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-700 mb-4">
              <svg
                class="w-8 h-8 text-slate-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"
                />
              </svg>
            </div>
            <p class="text-slate-500 dark:text-slate-400 font-medium">No active tournaments</p>
            <p class="text-sm text-slate-400 dark:text-slate-500 mt-1">
              Create a new tournament to get started
            </p>
          </div>
        <% else %>
          <%= for tournament <- @tournaments do %>
            <.link
              navigate={~p"/tournaments/#{tournament.id}/lobby"}
              class="block px-6 py-4 hover:bg-slate-50 dark:hover:bg-slate-750 transition-colors duration-150 group"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-2">
                    <h3 class="text-lg font-semibold text-slate-900 dark:text-white group-hover:text-amber-600 dark:group-hover:text-amber-400 transition-colors">
                      Sit & Go - {format_speed(tournament.speed)}
                    </h3>
                    <span class={"px-2.5 py-0.5 rounded-full text-xs font-medium #{
                      case tournament.status do
                        :active -> "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
                        :registering -> "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
                        :finished -> "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
                        _ -> "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-400"
                      end
                    }"}>
                      {String.capitalize(to_string(tournament.status))}
                    </span>
                  </div>
                  <div class="flex items-center gap-4 text-sm text-slate-600 dark:text-slate-400">
                    <span class="font-medium">Buy-in: {tournament.buy_in}</span>
                    <span>Stack: {tournament.starting_stack}</span>
                    <span>Players: {tournament.registered_count}/{tournament.max_players}</span>
                    <span>6-Max</span>
                  </div>
                </div>
                <div class="ml-4 flex items-center">
                  <svg
                    class="w-5 h-5 text-slate-400 group-hover:text-amber-500 dark:group-hover:text-amber-400 transition-colors"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                </div>
              </div>
            </.link>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp create_cash_game_form(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden sticky top-8">
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700 bg-gradient-to-r from-emerald-500 to-teal-500">
        <h2 class="text-xl font-semibold text-white">Create Cash Game</h2>
      </div>

      <.form for={@form} phx-submit="create_cash_game" class="p-6 space-y-4">
        <div>
          <.input
            type="number"
            name="cash_game[small_blind]"
            label="Small Blind"
            value="10"
            class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <div>
          <.input
            type="number"
            name="cash_game[big_blind]"
            label="Big Blind"
            value="20"
            class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <div>
          <.input
            type="number"
            name="cash_game[min_buyin]"
            label="Min Buy-in"
            value="200"
            class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <div>
          <.input
            type="number"
            name="cash_game[max_buyin]"
            label="Max Buy-in"
            value="2000"
            class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <div>
          <.input
            type="select"
            name="cash_game[table_type]"
            label="Table Type"
            options={[{"Heads-Up (2)", "two_max"}, {"3-Max", "three_max"}, {"4-Max", "four_max"}, {"6-Max", "six_max"}]}
            value="six_max"
            class="w-full select select-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <.button
          type="submit"
          class="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 px-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200"
        >
          <span class="flex items-center justify-center gap-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            Create Cash Game
          </span>
        </.button>
      </.form>
    </div>
    """
  end

  defp create_tournament_form(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden sticky top-8">
      <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700 bg-gradient-to-r from-amber-500 to-orange-500">
        <h2 class="text-xl font-semibold text-white">Create Tournament</h2>
      </div>

      <.form for={@form} phx-submit="create_tournament" class="p-6 space-y-4">
        <div>
          <.input
            type="number"
            name="tournament[buy_in]"
            label="Buy-in"
            value="100"
            class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <div>
          <.input
            type="select"
            name="tournament[speed]"
            label="Speed"
            options={[{"Regular (10min levels)", "regular"}, {"Turbo (5min levels)", "turbo"}, {"Hyper-Turbo (3min levels)", "hyper_turbo"}]}
            value="regular"
            class="w-full select select-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <div>
          <.input
            type="select"
            name="tournament[table_type]"
            label="Table Type"
            options={[{"Heads-Up (2)", "two_max"}, {"3-Max", "three_max"}, {"4-Max", "four_max"}, {"6-Max", "six_max"}]}
            value="six_max"
            class="w-full select select-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600 text-slate-900 dark:text-white"
          />
        </div>

        <.button
          type="submit"
          class="w-full bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white font-semibold py-3 px-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200"
        >
          <span class="flex items-center justify-center gap-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            Create Tournament
          </span>
        </.button>
      </.form>
    </div>
    """
  end
end
