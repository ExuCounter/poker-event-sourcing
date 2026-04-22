defmodule PokerWeb.PlayerLive.Dashboard do
  use PokerWeb, :live_view

  alias PokerWeb.Api.CashGames

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_tab: :cash_games,
       cash_games_list: CashGames.list_cash_games(),
       form: to_form(%{})
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
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
          {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/lobby")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create cash game: #{inspect(reason)}")}
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

  defp parse_table_type("six_max"), do: {:ok, :six_max}
  defp parse_table_type(_), do: {:error, "Invalid table type"}

  defp validate_buyins(min, max) when min <= max, do: :ok
  defp validate_buyins(_, _), do: {:error, "Min buy-in must be less than or equal to max buy-in"}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-4xl font-bold text-slate-900 dark:text-white mb-2">Poker Lobby</h1>
          <p class="text-slate-600 dark:text-slate-400">Join a game or create your own</p>
        </div>

        <!-- Tabs -->
        <div class="mb-6">
          <div class="border-b border-slate-200 dark:border-slate-700">
            <nav class="-mb-px flex space-x-8">
              <button
                phx-click="switch_tab"
                phx-value-tab="cash_games"
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
              </button>
              <button
                phx-click="switch_tab"
                phx-value-tab="tournaments"
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
              </button>
            </nav>
          </div>
        </div>

        <div class="grid lg:grid-cols-3 gap-8">
          <!-- Games List -->
          <div class="lg:col-span-2">
            <%= if @active_tab == :cash_games do %>
              <.cash_games_list cash_games={@cash_games_list} />
            <% else %>
              <.tournaments_list />
            <% end %>
          </div>

          <!-- Create Form -->
          <div class="lg:col-span-1">
            <%= if @active_tab == :cash_games do %>
              <.create_cash_game_form form={@form} />
            <% else %>
              <.create_tournament_form />
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
              navigate={~p"/tables/#{cash_game.table_id}/lobby"}
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

      <div class="px-6 py-12 text-center">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-700 mb-4">
          <svg class="w-8 h-8 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"
            />
          </svg>
        </div>
        <p class="text-slate-500 dark:text-slate-400 font-medium">Tournaments coming soon</p>
        <p class="text-sm text-slate-400 dark:text-slate-500 mt-1">
          Sit & Go tournaments will be available in a future update
        </p>
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
            options={[{"6-Max", "six_max"}]}
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

      <div class="p-6 text-center">
        <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-amber-100 dark:bg-amber-900/30 mb-4">
          <svg
            class="w-6 h-6 text-amber-600 dark:text-amber-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
        </div>
        <p class="text-slate-600 dark:text-slate-400 font-medium">Coming Soon</p>
        <p class="text-sm text-slate-500 dark:text-slate-500 mt-1">
          Tournament creation will be available in a future update
        </p>
      </div>
    </div>
    """
  end
end
