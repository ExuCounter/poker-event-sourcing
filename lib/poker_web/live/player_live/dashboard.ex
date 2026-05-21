defmodule PokerWeb.PlayerLive.Dashboard do
  use PokerWeb, :live_view

  alias PokerWeb.Api.CashGames
  alias PokerWeb.Api.Tournaments

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Poker.CashGames.PubSub.subscribe_to_cash_games_list()
      Poker.Tournaments.PubSub.subscribe_to_tournament_list()
      Poker.Wallet.PubSub.subscribe_to_wallet(socket.assigns.current_scope.user.id)
    end

    {:ok,
     assign(socket,
       cash_games_list: CashGames.list_cash_games(socket.assigns.current_scope),
       tournaments_list: Tournaments.list_tournaments(socket.assigns.current_scope),
       form: to_form(%{}),
       balance: get_balance(socket.assigns.current_scope.user.id)
     )}
  end

  @impl true
  def handle_info({:cash_games_list, _event, _data}, socket) do
    {:noreply,
     assign(socket, cash_games_list: CashGames.list_cash_games(socket.assigns.current_scope))}
  end

  @impl true
  def handle_info({:tournament_list, _event, _data}, socket) do
    {:noreply,
     assign(socket, tournaments_list: Tournaments.list_tournaments(socket.assigns.current_scope))}
  end

  @impl true
  def handle_info({:wallet, _event, _data}, socket) do
    {:noreply, assign(socket, balance: get_balance(socket.assigns.current_scope.user.id))}
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

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "You don't have permission to create tables.")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create cash game.")}
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

        {:error, :unauthorized} ->
          {:noreply,
           put_flash(socket, :error, "You don't have permission to create tournaments.")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create tournament.")}
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

  defp format_table_type(:two_max), do: "HU"
  defp format_table_type(:three_max), do: "3-max"
  defp format_table_type(:four_max), do: "4-max"
  defp format_table_type(:six_max), do: "6-max"
  defp format_table_type(_), do: "—"

  defp format_stakes(small_blind, big_blind), do: "$#{small_blind}/$#{big_blind}"

  defp seats_total(:two_max), do: 2
  defp seats_total(:three_max), do: 3
  defp seats_total(:four_max), do: 4
  defp seats_total(:six_max), do: 6
  defp seats_total(_), do: 6

  defp status_color(:live), do: "bg-[var(--pkr-positive)]"
  defp status_color(:waiting), do: "bg-[var(--pkr-accent)]"
  defp status_color(:paused), do: "bg-[var(--pkr-ink-3)]"
  defp status_color(:finished), do: "bg-[var(--pkr-danger)]"
  defp status_color(_), do: "bg-[var(--pkr-ink-3)]"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col font-[family-name:var(--pkr-font-ui)]">
      <.expiry_banner user={@current_scope.user} />
      <!-- Top bar -->
      <header class="h-14 flex items-center justify-between px-5 border-b border-[var(--pkr-line)]">
        <div class="flex items-center gap-3.5">
          <.link
            navigate={~p"/"}
            class="font-[family-name:var(--pkr-font-display)] text-[22px] italic flex items-baseline gap-1"
          >
            Poker
            <span class="text-[var(--pkr-ink-3)] text-[12px] not-italic font-[family-name:var(--pkr-font-mono)]">
              by Volodymyr Potiichuk
            </span>
          </.link>
        </div>
        <div class="flex items-center gap-3.5">
          <div class="flex items-center gap-2.5 px-3 py-1.5 rounded-lg border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)]">
            <span class="font-[family-name:var(--pkr-font-mono)] text-[9px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)]">
              BANKROLL
            </span>
            <span class="font-[family-name:var(--pkr-font-mono)] text-sm font-semibold text-[var(--pkr-ink-1)]">
              ${@balance}
            </span>
          </div>
          <span class="flex items-center gap-1.5 text-xs text-[var(--pkr-ink-3)]">
            {@current_scope.user.nickname}
            <.guest_badge :if={Poker.Accounts.guest?(@current_scope.user)} />
          </span>
          <.save_account_button user={@current_scope.user} />
          <.link
            :if={!Poker.Accounts.guest?(@current_scope.user)}
            href={~p"/users/settings"}
            class="px-3 py-1.5 rounded-md text-xs text-[var(--pkr-ink-2)] border border-[var(--pkr-line)] hover:bg-[var(--pkr-bg-2)] transition-all"
          >
            Settings
          </.link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            data-confirm={
              if Poker.Accounts.guest?(@current_scope.user),
                do:
                  "Ending your guest session deletes this account. Your wallet and history will be lost. Continue?"
            }
            class="px-3 py-1.5 rounded-md text-xs text-[var(--pkr-danger)] border border-[var(--pkr-danger)]/40 hover:bg-[var(--pkr-danger)]/15 transition-all"
          >
            {if Poker.Accounts.guest?(@current_scope.user), do: "End session", else: "Log out"}
          </.link>
        </div>
      </header>

      <div class="flex flex-1 min-h-0">
        <!-- Sidebar -->
        <aside class="w-[260px] border-r border-[var(--pkr-line)] flex flex-col shrink-0">
          <!-- Nav links (scrollable) -->
          <div class="p-5 pb-3">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2">
              PLAY
            </div>
            <div class="flex flex-col gap-0.5">
              <.link
                patch={~p"/cash"}
                class={"flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] transition-all " <>
                  if(@active_tab == :cash_games,
                    do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border border-[var(--pkr-line)]",
                    else: "text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50"
                  )}
              >
                <span class={"w-4 text-center " <> if(@active_tab == :cash_games, do: "text-[var(--pkr-accent)]", else: "text-[var(--pkr-ink-3)]")}>
                  &#x25D0;
                </span>
                <span class="flex-1">Cash games</span>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
                  {length(@cash_games_list)}
                </span>
              </.link>
              <.link
                patch={~p"/tournaments"}
                class={"flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] transition-all " <>
                  if(@active_tab == :tournaments,
                    do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border border-[var(--pkr-line)]",
                    else: "text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50"
                  )}
              >
                <span class={"w-4 text-center " <> if(@active_tab == :tournaments, do: "text-[var(--pkr-accent)]", else: "text-[var(--pkr-ink-3)]")}>
                  &#x25C7;
                </span>
                <span class="flex-1">Tournaments</span>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
                  {length(@tournaments_list)}
                </span>
              </.link>
            </div>

            <div class="mt-4">
              <.join_code_form title="JOIN WITH CODE" />
            </div>
          </div>

          <div class="px-5 pb-3 pt-2">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1">
              REVIEW
            </div>
            <div class="flex flex-col gap-0.5">
              <.link
                navigate={~p"/history"}
                class="flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50 transition-all"
              >
                <span class="w-4 text-center text-[var(--pkr-ink-3)]">&#x23F3;</span>
                <span class="flex-1">Hand history</span>
              </.link>
            </div>
          </div>

          <div class="flex-1"></div>
          
    <!-- Create form (sticky at bottom) — registered users only -->
          <div
            :if={!Poker.Accounts.guest?(@current_scope.user)}
            class="sticky bottom-0 p-4 pt-3 border-t border-[var(--pkr-line)] bg-[var(--pkr-bg-0)]"
          >
            <%= if @active_tab == :cash_games do %>
              <.create_cash_game_form form={@form} />
            <% else %>
              <.create_tournament_form form={@form} />
            <% end %>
          </div>
        </aside>
        
    <!-- Main content -->
        <main class="flex-1 p-6 overflow-auto">
          <.flash kind={:error} flash={@flash} />
          <.flash kind={:info} flash={@flash} />

          <header class="mb-6">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
              Lobby
            </div>
            <h1 class="font-[family-name:var(--pkr-font-display)] text-[44px] leading-none text-[var(--pkr-ink-1)]">
              {if @active_tab == :cash_games, do: "Cash games", else: "Tournaments"}
            </h1>
            <p class="text-[var(--pkr-ink-3)] text-[13px] mt-1.5">
              <%= if @active_tab == :cash_games do %>
                Live tables. Take a seat or watch from the rail.
              <% else %>
                On-demand sit-&amp;-gos. Register and play.
              <% end %>
            </p>
          </header>

          <%= if @active_tab == :cash_games do %>
            <.cash_games_table cash_games={@cash_games_list} />
          <% else %>
            <.tournaments_grid tournaments={@tournaments_list} />
          <% end %>
        </main>
      </div>
    </div>
    """
  end

  defp cash_games_table(assigns) do
    ~H"""
    <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
      <!-- Table header -->
      <div class="grid grid-cols-[1.6fr_0.8fr_0.6fr_0.6fr_0.8fr] px-4 py-2.5 border-b border-[var(--pkr-line)] font-[family-name:var(--pkr-font-mono)] text-[10px] tracking-[0.1em] text-[var(--pkr-ink-3)] uppercase">
        <span>TABLE</span>
        <span>STAKES</span>
        <span>SEATS</span>
        <span>STATUS</span>
        <span class="text-right">ACTION</span>
      </div>

      <%= if Enum.empty?(@cash_games) do %>
        <div class="px-6 py-16 text-center">
          <p class="text-[var(--pkr-ink-3)] font-medium">No active cash games</p>
          <p class="text-sm text-[var(--pkr-ink-3)]/70 mt-1">Create a new cash game to get started</p>
        </div>
      <% else %>
        <%= for {cash_game, index} <- Enum.with_index(@cash_games) do %>
          <.link
            navigate={~p"/cash/#{cash_game.table_id}/lobby"}
            class={"grid grid-cols-[1.6fr_0.8fr_0.6fr_0.6fr_0.8fr] px-4 py-3.5 items-center text-[13px] hover:bg-[var(--pkr-bg-2)]/50 transition-colors group " <>
              if(index < length(@cash_games) - 1, do: "border-b border-dashed border-[var(--pkr-line)]", else: "")}
          >
            <!-- Table name + type -->
            <div class="flex items-center gap-2.5">
              <.mini_table
                seated={cash_game.seated_count || 0}
                total={seats_total(cash_game.table_type)}
              />
              <div>
                <div class="font-medium text-[var(--pkr-ink-1)] group-hover:text-[var(--pkr-accent)] transition-colors">
                  NL Hold'em &middot; {format_stakes(cash_game.small_blind, cash_game.big_blind)}
                </div>
                <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
                  {format_table_type(cash_game.table_type)} &middot; Buy-in {cash_game.min_buyin}&ndash;{cash_game.max_buyin}
                </div>
              </div>
            </div>
            <!-- Stakes -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-1)]">
              {format_stakes(cash_game.small_blind, cash_game.big_blind)}
            </span>
            <!-- Seats -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[12px]">
              <span class="text-[var(--pkr-ink-1)]">{cash_game.seated_count || 0}</span><span class="text-[var(--pkr-ink-3)]">/{seats_total(cash_game.table_type)}</span>
            </span>
            <!-- Status -->
            <span class="inline-flex items-center gap-1.5 text-[12px]">
              <span class={"w-1.5 h-1.5 rounded-full " <> status_color(cash_game.table_status)}>
              </span>
              <span class="text-[var(--pkr-ink-3)]">{format_status(cash_game.table_status)}</span>
            </span>
            <!-- Action -->
            <div class="text-right">
              <span class="px-3 py-1.5 rounded-lg text-[12px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)]">
                Take a seat
              </span>
            </div>
          </.link>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp mini_table(assigns) do
    total = assigns.total
    seated = assigns.seated

    dots =
      for i <- 0..(total - 1) do
        angle = i / total * :math.pi() * 2 - :math.pi() / 2
        x = 18 + :math.cos(angle) * 16
        y = 11 + :math.sin(angle) * 9
        %{x: x, y: y, filled: i < seated}
      end

    assigns = assign(assigns, dots: dots)

    ~H"""
    <div class="relative w-9 h-[22px] rounded-full bg-[var(--pkr-bg-2)] border border-[var(--pkr-accent)]/30 shrink-0">
      <%= for dot <- @dots do %>
        <div
          class={"absolute w-1 h-1 rounded-full " <> if(dot.filled, do: "bg-[var(--pkr-accent)]", else: "bg-[var(--pkr-line)]")}
          style={"left: #{dot.x - 2}px; top: #{dot.y - 2}px"}
        />
      <% end %>
    </div>
    """
  end

  defp tournaments_grid(assigns) do
    ~H"""
    <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
      <!-- Table header -->
      <div class="grid grid-cols-[1.6fr_0.8fr_0.6fr_0.6fr_0.6fr_0.8fr] px-4 py-2.5 border-b border-[var(--pkr-line)] font-[family-name:var(--pkr-font-mono)] text-[10px] tracking-[0.1em] text-[var(--pkr-ink-3)] uppercase">
        <span>TOURNAMENT</span>
        <span>BUY-IN</span>
        <span>PLAYERS</span>
        <span>SPEED</span>
        <span>STATUS</span>
        <span class="text-right">ACTION</span>
      </div>

      <%= if Enum.empty?(@tournaments) do %>
        <div class="px-6 py-16 text-center">
          <p class="text-[var(--pkr-ink-3)] font-medium">No active tournaments</p>
          <p class="text-sm text-[var(--pkr-ink-3)]/70 mt-1">
            Create a new tournament to get started
          </p>
        </div>
      <% else %>
        <%= for {tournament, index} <- Enum.with_index(@tournaments) do %>
          <.link
            navigate={~p"/tournaments/#{tournament.id}/lobby"}
            class={"grid grid-cols-[1.6fr_0.8fr_0.6fr_0.6fr_0.6fr_0.8fr] px-4 py-3 items-center text-[13px] hover:bg-[var(--pkr-bg-2)]/50 transition-colors group " <>
              if(index < length(@tournaments) - 1, do: "border-b border-dashed border-[var(--pkr-line)]", else: "")}
          >
            <!-- Name + type -->
            <div>
              <div class="font-medium text-[var(--pkr-ink-1)] group-hover:text-[var(--pkr-accent)] transition-colors">
                Sit &amp; Go &ndash; {format_speed(tournament.speed)}
              </div>
              <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
                {format_table_type(tournament.table_type)} &middot; NLHE
              </div>
            </div>
            <!-- Buy-in -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-1)]">
              ${tournament.buy_in}
            </span>
            <!-- Players -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[12px]">
              <span class="text-[var(--pkr-ink-1)]">{tournament.registered_count}</span><span class="text-[var(--pkr-ink-3)]">/{tournament.max_players}</span>
            </span>
            <!-- Speed -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[12px] text-[var(--pkr-ink-2)]">
              {format_speed(tournament.speed)}
            </span>
            <!-- Status -->
            <span class="inline-flex items-center gap-1.5 text-[12px]">
              <span class={"w-1.5 h-1.5 rounded-full " <> if(tournament.status == :active, do: "bg-[var(--pkr-positive)]", else: "bg-[var(--pkr-accent)]")}>
              </span>
              <span class="text-[var(--pkr-ink-3)]">
                {format_tournament_status(tournament.status)}
              </span>
            </span>
            <!-- Action -->
            <div class="text-right">
              <span class="px-3 py-1.5 rounded-lg text-[12px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)]">
                {if tournament.status == :active, do: "Watch", else: "Register"}
              </span>
            </div>
          </.link>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp create_cash_game_form(assigns) do
    ~H"""
    <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
      <div class="px-4 py-3 border-b border-[var(--pkr-line)]">
        <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
          CREATE CASH GAME
        </div>
      </div>
      <.form for={@form} phx-submit="create_cash_game" class="p-4 space-y-3">
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
              SB
            </label>
            <input
              type="number"
              name="cash_game[small_blind]"
              value="10"
              class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)]"
            />
          </div>
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
              BB
            </label>
            <input
              type="number"
              name="cash_game[big_blind]"
              value="20"
              class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)]"
            />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
              MIN BUY-IN
            </label>
            <input
              type="number"
              name="cash_game[min_buyin]"
              value="200"
              class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)]"
            />
          </div>
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
              MAX BUY-IN
            </label>
            <input
              type="number"
              name="cash_game[max_buyin]"
              value="2000"
              class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)]"
            />
          </div>
        </div>
        <div>
          <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
            TABLE TYPE
          </label>
          <select
            name="cash_game[table_type]"
            class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)]"
          >
            <option value="two_max">Heads-Up (2)</option>
            <option value="three_max">3-Max</option>
            <option value="four_max">4-Max</option>
            <option value="six_max" selected>6-Max</option>
          </select>
        </div>
        <button
          type="submit"
          class="w-full py-2 rounded-lg text-[13px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
        >
          + Create table
        </button>
      </.form>
    </div>
    """
  end

  defp create_tournament_form(assigns) do
    ~H"""
    <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
      <div class="px-4 py-3 border-b border-[var(--pkr-line)]">
        <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
          CREATE TOURNAMENT
        </div>
      </div>
      <.form for={@form} phx-submit="create_tournament" class="p-4 space-y-3">
        <div>
          <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
            BUY-IN
          </label>
          <input
            type="number"
            name="tournament[buy_in]"
            value="100"
            class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)]"
          />
        </div>
        <div>
          <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
            SPEED
          </label>
          <select
            name="tournament[speed]"
            class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)]"
          >
            <option value="regular">Regular (10min)</option>
            <option value="turbo">Turbo (5min)</option>
            <option value="hyper_turbo">Hyper-Turbo (3min)</option>
          </select>
        </div>
        <div>
          <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1">
            TABLE TYPE
          </label>
          <select
            name="tournament[table_type]"
            class="w-full px-2.5 py-1.5 rounded-md text-[13px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)]"
          >
            <option value="two_max">Heads-Up (2)</option>
            <option value="three_max">3-Max</option>
            <option value="four_max">4-Max</option>
            <option value="six_max" selected>6-Max</option>
          </select>
        </div>
        <button
          type="submit"
          class="w-full py-2 rounded-lg text-[13px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
        >
          + Create tournament
        </button>
      </.form>
    </div>
    """
  end

  defp format_status(:live), do: "live"
  defp format_status(:waiting), do: "waiting"
  defp format_status(:paused), do: "paused"
  defp format_status(:finished), do: "finished"
  defp format_status(_), do: "—"

  defp format_tournament_status(:active), do: "live"
  defp format_tournament_status(:registering), do: "registering"
  defp format_tournament_status(:finished), do: "finished"
  defp format_tournament_status(_), do: "—"
end
