defmodule PokerWeb.PlayerLive.Lobby do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    case Tables.get_lobby(table_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Table lobby not found")
         |> push_navigate(to: ~p"/")}

      lobby ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:lobby")
        end

        {:ok,
         assign(socket,
           lobby: lobby,
           table_id: table_id,
           user_id: socket.assigns.current_scope.user.id
         )}
    end
  end

  @impl true
  def handle_event("join_table", _params, socket) do
    case Tables.join_participant(socket.assigns.current_scope, %{
           table_id: socket.assigns.table_id
         }) do
      {:ok, _participant_id} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the table")
         |> assign(lobby: Tables.get_lobby(socket.assigns.table_id))}

      {:error, %{message: message}} ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join table: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("start_table", _params, socket) do
    case Tables.start_table(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Table started!")
         |> push_navigate(to: ~p"/tables/#{socket.assigns.table_id}/game")}

      {:error, :table_already_started} ->
        {:noreply, put_flash(socket, :error, "Table has already started")}

      {:error, :not_enough_participants} ->
        {:noreply, put_flash(socket, :error, "Need at least 2 players to start")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start table: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:table_lobby, :table_started, %{table_id: table_id}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/game")}
  end

  def handle_info({:table_lobby, _event, _data}, socket) do
    lobby = Tables.get_lobby(socket.assigns.table_id)
    {:noreply, assign(socket, lobby: lobby)}
  end

  defp user_has_joined?(participants, user_id) do
    Enum.any?(participants, fn p -> p.player_id == user_id end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash kind={:error} flash={@flash} />
    <.flash kind={:info} flash={@flash} />

    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Back Navigation -->
        <div class="mb-6">
          <.link
            navigate={~p"/"}
            class="inline-flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors group"
          >
            <svg class="w-4 h-4 group-hover:-translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Back to Tables List
          </.link>
        </div>

        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-4xl font-bold text-slate-900 dark:text-white mb-2">Table Lobby</h1>
          <p class="text-slate-600 dark:text-slate-400">Get ready to play some poker</p>
        </div>

        <div class="grid gap-6">
          <!-- Table Information Card -->
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700 bg-gradient-to-r from-emerald-500 to-teal-500">
              <div class="flex items-center justify-between">
                <h2 class="text-xl font-semibold text-white">Table Information</h2>
                <span class={"px-3 py-1 rounded-full text-sm font-medium #{
                  case @lobby.status do
                    :live -> "bg-white/20 text-white border border-white/30"
                    :waiting -> "bg-amber-500/20 text-white border border-amber-300/30"
                    _ -> "bg-white/10 text-white border border-white/20"
                  end
                }"}>
                  {String.capitalize(to_string(@lobby.status))}
                </span>
              </div>
            </div>

            <div class="p-6">
              <div class="grid grid-cols-2 md:grid-cols-3 gap-6">
                <div class="space-y-1">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Table Type</p>
                  <p class="text-lg font-semibold text-slate-900 dark:text-white capitalize">
                    {String.replace(to_string(@lobby.table_type), "_", " ")}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Small Blind</p>
                  <p class="text-lg font-semibold text-slate-900 dark:text-white">
                    <span class="text-emerald-600 dark:text-emerald-400">$</span>{@lobby.small_blind}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Big Blind</p>
                  <p class="text-lg font-semibold text-slate-900 dark:text-white">
                    <span class="text-emerald-600 dark:text-emerald-400">$</span>{@lobby.big_blind}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Starting Stack</p>
                  <p class="text-lg font-semibold text-slate-900 dark:text-white">
                    <span class="text-emerald-600 dark:text-emerald-400">$</span>{@lobby.starting_stack}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Players</p>
                  <p class="text-lg font-semibold text-slate-900 dark:text-white">
                    {@lobby.seated_count}<span class="text-slate-400 dark:text-slate-500">/{@lobby.seats_count}</span>
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">Available Seats</p>
                  <p class="text-lg font-semibold text-slate-900 dark:text-white">
                    {@lobby.seats_count - @lobby.seated_count}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Players Card -->
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden">
            <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
              <h2 class="text-xl font-semibold text-slate-900 dark:text-white">
                Players <span class="text-slate-500 dark:text-slate-400">({@lobby.seated_count})</span>
              </h2>
            </div>

            <div class="p-6">
              <%= if Enum.empty?(@lobby.participants) do %>
                <div class="py-12 text-center">
                  <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-700 mb-4">
                    <svg class="w-8 h-8 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                  </div>
                  <p class="text-slate-500 dark:text-slate-400 font-medium">Waiting for players</p>
                  <p class="text-sm text-slate-400 dark:text-slate-500 mt-1">Be the first to join this table</p>
                </div>
              <% else %>
                <div class="grid sm:grid-cols-2 gap-3 mb-6">
                  <%= for participant <- @lobby.participants do %>
                    <div class="flex items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-750 border border-slate-200 dark:border-slate-600">
                      <div class="flex-shrink-0 w-10 h-10 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center text-white font-semibold text-sm">
                        {String.first(participant.email) |> String.upcase()}
                      </div>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                          {participant.email}
                        </p>
                        <div class="flex items-center gap-1.5 mt-0.5">
                          <div class="w-2 h-2 bg-emerald-500 rounded-full"></div>
                          <span class="text-xs text-slate-500 dark:text-slate-400">Active</span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Action Buttons -->
              <div class="flex flex-wrap gap-3">
                <%= cond do %>
                  <% user_has_joined?(@lobby.participants, @user_id) && @lobby.status == :live -> %>
                    <.button
                      navigate={~p"/tables/#{@lobby.id}/game"}
                      class="flex-1 bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white font-semibold py-3 px-6 rounded-lg shadow-md hover:shadow-lg transition-all duration-200"
                    >
                      <span class="flex items-center justify-center gap-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10l-2 1m0 0l-2-1m2 1v2.5M20 7l-2 1m2-1l-2-1m2 1v2.5M14 4l-2-1-2 1M4 7l2-1M4 7l2 1M4 7v2.5M12 21l-2-1m2 1l2-1m-2 1v-2.5M6 18l-2-1v-2.5M18 18l2-1v-2.5" />
                        </svg>
                        Enter Game
                      </span>
                    </.button>

                  <% @lobby.seated_count < @lobby.seats_count -> %>
                    <.button
                      phx-click="join_table"
                      class="flex-1 bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 px-6 rounded-lg shadow-md hover:shadow-lg transition-all duration-200"
                    >
                      <span class="flex items-center justify-center gap-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                        </svg>
                        Join Table
                      </span>
                    </.button>

                  <% true -> %>
                    <div class="flex-1 flex items-center justify-center px-6 py-3 bg-slate-100 dark:bg-slate-700 rounded-lg border border-slate-200 dark:border-slate-600">
                      <svg class="w-5 h-5 text-slate-400 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                      <span class="text-slate-600 dark:text-slate-400 font-medium">
                        Table Full ({@lobby.seats_count} max)
                      </span>
                    </div>
                <% end %>

                <%= if @lobby.status in [:waiting, :live] && @lobby.seated_count >= 2 && @lobby.creator_id == @user_id do %>
                  <.button
                    phx-click="start_table"
                    class="flex-1 bg-gradient-to-r from-blue-500 to-indigo-500 hover:from-blue-600 hover:to-indigo-600 text-white font-semibold py-3 px-6 rounded-lg shadow-md hover:shadow-lg transition-all duration-200"
                  >
                    <span class="flex items-center justify-center gap-2">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      Start Game
                    </span>
                  </.button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
