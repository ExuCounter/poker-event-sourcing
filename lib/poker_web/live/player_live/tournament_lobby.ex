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
        seating = Poker.Tournaments.Queries.table_by_source(tournament_id)

        if connected?(socket) do
          Poker.Tournaments.PubSub.subscribe_to_tournament(tournament_id)

          if seating do
            Poker.Tables.PubSub.subscribe_to_lobby(seating.id)
          end
        end

        {:ok,
         assign(socket,
           tournament: tournament,
           tournament_id: tournament_id,
           seating: seating,
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

        {:noreply,
         assign(socket,
           tournament: tournament,
           registered_players: find_registered_players(tournament.player_ids)
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  @impl true
  def handle_info({:table_lobby, :table_started, %{table_id: table_id}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/game")}
  end

  def handle_info({:table_lobby, _event, _data}, socket) do
    seating = Poker.Tournaments.Queries.table_by_source(socket.assigns.tournament_id)
    {:noreply, assign(socket, seating: seating)}
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

  defp format_table_type(:two_max), do: "HU"
  defp format_table_type(:three_max), do: "3-max"
  defp format_table_type(:four_max), do: "4-max"
  defp format_table_type(:six_max), do: "6-max"
  defp format_table_type(_), do: "—"

  defp level_duration(:regular), do: "10 min"
  defp level_duration(:turbo), do: "5 min"
  defp level_duration(:hyper_turbo), do: "3 min"

  @impl true
  def render(assigns) do
    prize_pool = (assigns.tournament.buy_in || 0) * (assigns.tournament.registered_count || 0)
    assigns = assign(assigns, prize_pool: prize_pool)

    ~H"""
    <div class="min-h-screen flex flex-col font-[family-name:var(--pkr-font-ui)]">
      <!-- Top bar -->
      <div class="h-14 flex items-center px-5 border-b border-[var(--pkr-line)]">
        <.link
          navigate={~p"/"}
          class="font-[family-name:var(--pkr-font-mono)] text-xs text-[var(--pkr-ink-3)] hover:text-[var(--pkr-ink-2)] transition-all mr-4"
        >
          &larr; Lobby
        </.link>
        <.link
          navigate={~p"/"}
          class="font-[family-name:var(--pkr-font-display)] text-[22px] italic flex items-baseline gap-1"
        >
          Poker
          <span class="text-[var(--pkr-ink-3)] text-[12px] not-italic font-[family-name:var(--pkr-font-mono)]">
            by Volodymyr Potiichuk
          </span>
        </.link>
        <div class="flex-1"></div>
        <.share_code_chip :if={@tournament.code} code={@tournament.code} class="mr-2" />
        <span class="px-2.5 py-1 rounded-full text-xs border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-2)] font-[family-name:var(--pkr-font-mono)]">
          Buy-in ${@tournament.buy_in}
        </span>
        <span class="ml-2 px-2.5 py-1 rounded-full text-xs border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-2)] font-[family-name:var(--pkr-font-mono)]">
          NLHE &middot; {format_table_type(@tournament.table_type)}
        </span>
      </div>

      <.flash kind={:error} flash={@flash} />
      <.flash kind={:info} flash={@flash} />

      <div class="flex flex-1 min-h-0">
        <!-- Left: Tournament info + blind structure -->
        <div class="flex-1 p-6 overflow-auto">
          <!-- Tournament header -->
          <div class="mb-6">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
              NLHE &middot; {String.upcase(to_string(@tournament.status))}
            </div>
            <h1 class="font-[family-name:var(--pkr-font-display)] text-[36px] leading-none text-[var(--pkr-ink-1)]">
              Sit &amp; Go &ndash; {format_speed(@tournament.speed)}
            </h1>
            <p class="text-[var(--pkr-ink-3)] text-[13px] mt-2">
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
          
    <!-- Stats grid -->
          <div class="grid grid-cols-3 gap-3 mb-6">
            <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[9px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                Buy-in
              </div>
              <div class="font-[family-name:var(--pkr-font-display)] text-[24px] text-[var(--pkr-ink-1)] mt-1">
                ${@tournament.buy_in}
              </div>
            </div>
            <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[9px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                Prize Pool
              </div>
              <div class="font-[family-name:var(--pkr-font-display)] text-[24px] text-[var(--pkr-accent)] mt-1">
                ${@prize_pool}
              </div>
            </div>
            <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[9px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                Players
              </div>
              <div class="font-[family-name:var(--pkr-font-mono)] text-[24px] font-semibold text-[var(--pkr-ink-1)] mt-1">
                {@tournament.registered_count}<span class="text-[var(--pkr-ink-3)]">/{@tournament.max_players}</span>
              </div>
            </div>
          </div>
          
    <!-- Blind structure -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
            <div class="px-4 py-3 border-b border-[var(--pkr-line)]">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                BLIND STRUCTURE
              </div>
            </div>
            <div class="grid grid-cols-[0.5fr_1fr_1fr_1fr] px-4 py-2 border-b border-[var(--pkr-line)] font-[family-name:var(--pkr-font-mono)] text-[10px] tracking-[0.1em] text-[var(--pkr-ink-3)] uppercase">
              <span>LVL</span>
              <span>SB</span>
              <span>BB</span>
              <span>DURATION</span>
            </div>
            <%= for level <- @blind_levels do %>
              <div class={"grid grid-cols-[0.5fr_1fr_1fr_1fr] px-4 py-2 text-[13px] border-b border-dashed border-[var(--pkr-line)] last:border-0 " <>
                if(level.level == @tournament.current_level and @tournament.status == :active, do: "bg-[var(--pkr-accent)]/10", else: "")}>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-2)] font-medium">
                  {level.level}
                  <%= if level.level == @tournament.current_level and @tournament.status == :active do %>
                    <span class="text-[var(--pkr-accent)] text-[10px] ml-1">&#9679;</span>
                  <% end %>
                </span>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-1)]">
                  {level.small_blind}
                </span>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-1)]">
                  {level.big_blind}
                </span>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-3)]">
                  {div(level.duration_seconds, 60)} min
                </span>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Right rail -->
        <aside class="w-[360px] border-l border-[var(--pkr-line)] p-5 flex flex-col gap-3.5 overflow-auto">
          <div>
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
              TOURNAMENT
            </div>
            <h2 class="font-[family-name:var(--pkr-font-display)] text-[28px] leading-none text-[var(--pkr-ink-1)]">
              Sit &amp; Go
            </h2>
            <div class="font-[family-name:var(--pkr-font-mono)] text-xs text-[var(--pkr-ink-3)] mt-1">
              {format_speed(@tournament.speed)} &middot; {level_duration(@tournament.speed)} levels
            </div>
          </div>
          
    <!-- Info -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)] mb-2.5">
              INFO
            </div>
            <div class="space-y-0">
              <.stat_row label="Game" value="No-Limit Hold'em" />
              <.stat_row label="Buy-in" value={"$#{@tournament.buy_in}"} />
              <.stat_row label="Stack" value={"#{@tournament.starting_stack}"} />
              <.stat_row label="Speed" value={format_speed(@tournament.speed)} />
              <.stat_row label="Table" value={format_table_type(@tournament.table_type)} />
            </div>
          </div>
          
    <!-- Registered players -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)] mb-2.5">
              PLAYERS ({@tournament.registered_count}/{@tournament.max_players})
            </div>
            <%= if Enum.empty?(@registered_players) do %>
              <div class="text-sm text-[var(--pkr-ink-3)] text-center py-4">
                No players registered yet
              </div>
            <% else %>
              <div class="space-y-1.5">
                <%= for player <- @registered_players do %>
                  <div class="flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg bg-[var(--pkr-bg-2)]/50">
                    <div class="w-7 h-7 rounded-full bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] flex items-center justify-center text-[10px] font-semibold text-[var(--pkr-ink-2)]">
                      {String.first(player.email) |> String.upcase()}
                    </div>
                    <span class="text-[13px] text-[var(--pkr-ink-1)] truncate flex-1">
                      {player.email}
                    </span>
                    <%= if player.id == @user_id do %>
                      <span class="text-[10px] text-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)]">
                        YOU
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="flex-1"></div>
          
    <!-- Actions -->
          <%= if @tournament.status == :registering do %>
            <%= if @user_id in (@tournament.player_ids || []) do %>
              <div class="w-full py-3 rounded-xl text-sm text-center text-[var(--pkr-accent)] border border-[var(--pkr-accent)]/30 bg-[var(--pkr-accent)]/5 font-[family-name:var(--pkr-font-mono)]">
                Registered &middot; waiting for players
              </div>
            <% else %>
              <button
                phx-click="register"
                class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
              >
                Register &middot; Buy-in ${@tournament.buy_in}
              </button>
            <% end %>
          <% end %>

          <%= if @tournament.status == :active && @seating do %>
            <.link
              navigate={~p"/tables/#{@seating.id}/game"}
              class="block w-full text-center py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all"
            >
              <%= if @user_id in (@tournament.player_ids || []) do %>
                Enter Table
              <% else %>
                Watch Game
              <% end %>
            </.link>
          <% end %>
        </aside>
      </div>
    </div>
    """
  end

  defp stat_row(assigns) do
    ~H"""
    <div class="flex justify-between items-baseline text-[12px] py-1.5 border-b border-dashed border-[var(--pkr-line)] last:border-0">
      <span class="text-[var(--pkr-ink-3)]">{@label}</span>
      <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-1)] font-medium">
        {@value}
      </span>
    </div>
    """
  end
end
