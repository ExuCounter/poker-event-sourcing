defmodule PokerWeb.PlayerLive.Dashboard do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Poker.PubSub, "table_list")
    end

    {:ok, assign(socket, tables_list: Tables.list_tables(), form: to_form(%{}))}
  end

  @impl true
  def handle_event("create_table", %{"table" => params}, socket) do
    settings = %{
      small_blind: String.to_integer(params["small_blind"]),
      big_blind: String.to_integer(params["big_blind"]),
      starting_stack: String.to_integer(params["starting_stack"]),
      timeout_seconds: String.to_integer(params["timeout_seconds"]),
      table_type: String.to_existing_atom(params["table_type"])
    }

    case Tables.create_table(socket.assigns.current_scope, settings) do
      {:ok, %{table_id: table_id}} ->
        {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/lobby")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create table: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:table_list, _event, _data}, socket) do
    {:noreply, assign(socket, tables_list: Tables.list_tables())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-4xl font-bold text-slate-900 dark:text-white mb-2">Poker Lobby</h1>
          <p class="text-slate-600 dark:text-slate-400">Join a table or create your own game</p>
        </div>

        <div class="grid lg:grid-cols-3 gap-8">
          <!-- Tables List -->
          <div class="lg:col-span-2">
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
              <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white">Active Tables</h2>
              </div>

              <div class="divide-y divide-slate-200 dark:divide-slate-700">
                <%= if Enum.empty?(@tables_list) do %>
                  <div class="px-6 py-12 text-center">
                    <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-700 mb-4">
                      <svg class="w-8 h-8 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                    </div>
                    <p class="text-slate-500 dark:text-slate-400 font-medium">No active tables</p>
                    <p class="text-sm text-slate-400 dark:text-slate-500 mt-1">Create a new table to get started</p>
                  </div>
                <% else %>
                  <%= for table <- @tables_list do %>
                    <.link
                      navigate={~p"/tables/#{table.id}/lobby"}
                      class="block px-6 py-4 hover:bg-slate-50 dark:hover:bg-slate-750 transition-colors duration-150 group"
                    >
                      <div class="flex items-center justify-between">
                        <div class="flex-1">
                          <div class="flex items-center gap-3 mb-2">
                            <h3 class="text-lg font-semibold text-slate-900 dark:text-white group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                              No-Limit Hold'em
                            </h3>
                            <span class={"px-2.5 py-0.5 rounded-full text-xs font-medium #{
                              case table.status do
                                "live" -> "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
                                "waiting" -> "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
                                _ -> "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-400"
                              end
                            }"}>
                              {String.capitalize(to_string(table.status))}
                            </span>
                          </div>
                          <div class="flex items-center gap-4 text-sm text-slate-600 dark:text-slate-400">
                            <div class="flex items-center gap-1.5">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                              </svg>
                              <span class="font-medium">{table.seated_count}/{table.seats_count} players</span>
                            </div>
                            <div class="flex items-center gap-1.5">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                              </svg>
                              <span>6-Max</span>
                            </div>
                          </div>
                        </div>
                        <div class="ml-4 flex items-center">
                          <svg class="w-5 h-5 text-slate-400 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                          </svg>
                        </div>
                      </div>
                    </.link>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Create Table Form -->
          <div class="lg:col-span-1">
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden sticky top-8">
              <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700 bg-gradient-to-r from-emerald-500 to-teal-500">
                <h2 class="text-xl font-semibold text-white">Create New Table</h2>
              </div>

              <.form for={@form} phx-submit="create_table" class="p-6 space-y-4">
                <div>
                  <.input
                    type="number"
                    name="table[small_blind]"
                    label="Small Blind"
                    value="10"
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <div>
                  <.input
                    type="number"
                    name="table[big_blind]"
                    label="Big Blind"
                    value="20"
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <div>
                  <.input
                    type="number"
                    name="table[starting_stack]"
                    label="Starting Stack"
                    value="1000"
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <div>
                  <.input
                    type="number"
                    name="table[timeout_seconds]"
                    label="Timeout (seconds)"
                    value="90"
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <div>
                  <.input
                    type="select"
                    name="table[table_type]"
                    label="Table Type"
                    options={[{"6-Max", "six_max"}]}
                    value="six_max"
                    class="w-full select select-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <.button
                  type="submit"
                  class="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 px-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200"
                >
                  <span class="flex items-center justify-center gap-2">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                    </svg>
                    Create Table
                  </span>
                </.button>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
