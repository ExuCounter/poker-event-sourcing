defmodule PokerWeb.PlayerLive.HandHistory do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, hands: [], next_cursor: nil, game_mode_filter: nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    game_mode_filter =
      case socket.assigns.live_action do
        :cash -> :cash_game
        :tournaments -> :tournament
        _ -> nil
      end

    {hands, next_cursor} =
      Tables.list_hand_history(socket.assigns.current_scope, game_mode: game_mode_filter)

    {:noreply,
     assign(socket, hands: hands, next_cursor: next_cursor, game_mode_filter: game_mode_filter)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    {more_hands, next_cursor} =
      Tables.list_hand_history(socket.assigns.current_scope,
        game_mode: socket.assigns.game_mode_filter,
        cursor: socket.assigns.next_cursor
      )

    {:noreply,
     assign(socket, hands: socket.assigns.hands ++ more_hands, next_cursor: next_cursor)}
  end

  # Private helpers

  defp format_date(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M")
  end

  defp format_date(_), do: "—"

  defp format_game_mode(:cash_game), do: "Cash"
  defp format_game_mode(:tournament), do: "Tournament"
  defp format_game_mode(_), do: "—"

  defp format_finish_reason(:showdown), do: "Showdown"
  defp format_finish_reason(:all_folded), do: "All folded"
  defp format_finish_reason(:all_in_runout), do: "All-in runout"
  defp format_finish_reason(_), do: "—"

  defp net_result(amount_won, amount_invested), do: amount_won - amount_invested

  defp result_class(amount_won, amount_invested) do
    case net_result(amount_won, amount_invested) do
      net when net > 0 -> "text-[var(--pkr-positive)]"
      net when net < 0 -> "text-[var(--pkr-danger)]"
      _ -> "text-[var(--pkr-ink-3)]"
    end
  end

  defp format_result(amount_won, amount_invested) do
    case net_result(amount_won, amount_invested) do
      net when net > 0 -> "+$#{net}"
      net when net < 0 -> "-$#{abs(net)}"
      _ -> "$0"
    end
  end

  defp replay_path(%{table_id: table_id, hand_id: hand_id}),
    do: ~p"/tables/#{table_id}/replay/#{hand_id}"

  defp lobby_path(%{game_mode: :tournament, source_id: source_id}) when is_binary(source_id),
    do: ~p"/tournaments/#{source_id}/lobby"

  defp lobby_path(%{table_id: table_id}),
    do: ~p"/cash/#{table_id}/lobby"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col font-[family-name:var(--pkr-font-ui)]">
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
          <.link
            navigate={~p"/"}
            class="px-3 py-1.5 rounded-md text-xs text-[var(--pkr-ink-2)] border border-[var(--pkr-line)] hover:bg-[var(--pkr-bg-2)] transition-all"
          >
            ← Lobby
          </.link>
        </div>
      </header>

      <!-- Main content -->
      <main class="flex-1 p-6 overflow-auto max-w-5xl w-full mx-auto">
        <.flash kind={:error} flash={@flash} />
        <.flash kind={:info} flash={@flash} />

        <header class="mb-6">
          <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
            Player
          </div>
          <h1 class="font-[family-name:var(--pkr-font-display)] text-[44px] leading-none text-[var(--pkr-ink-1)]">
            Hand history
          </h1>
          <p class="text-[var(--pkr-ink-3)] text-[13px] mt-1.5">
            All hands you were dealt into, most recent first.
          </p>
        </header>

        <!-- Filter tabs -->
        <div class="flex items-center gap-1 mb-4">
          <.link
            patch={~p"/history"}
            class={"px-3 py-1.5 rounded-lg text-[12px] font-[family-name:var(--pkr-font-mono)] border transition-all " <>
              if(@live_action == :all,
                do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border-[var(--pkr-line)]",
                else: "text-[var(--pkr-ink-3)] border-transparent hover:bg-[var(--pkr-bg-2)]/50"
              )}
          >
            All
          </.link>
          <.link
            patch={~p"/history/cash"}
            class={"px-3 py-1.5 rounded-lg text-[12px] font-[family-name:var(--pkr-font-mono)] border transition-all " <>
              if(@live_action == :cash,
                do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border-[var(--pkr-line)]",
                else: "text-[var(--pkr-ink-3)] border-transparent hover:bg-[var(--pkr-bg-2)]/50"
              )}
          >
            Cash
          </.link>
          <.link
            patch={~p"/history/tournaments"}
            class={"px-3 py-1.5 rounded-lg text-[12px] font-[family-name:var(--pkr-font-mono)] border transition-all " <>
              if(@live_action == :tournaments,
                do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border-[var(--pkr-line)]",
                else: "text-[var(--pkr-ink-3)] border-transparent hover:bg-[var(--pkr-bg-2)]/50"
              )}
          >
            Tournaments
          </.link>
        </div>

        <!-- Hands table -->
        <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
          <div class="grid grid-cols-[1.4fr_0.6fr_0.7fr_0.7fr_1.2fr_0.6fr] px-4 py-2.5 border-b border-[var(--pkr-line)] font-[family-name:var(--pkr-font-mono)] text-[10px] tracking-[0.1em] text-[var(--pkr-ink-3)] uppercase">
            <span>DATE</span>
            <span>LOBBY</span>
            <span>POT</span>
            <span>RESULT</span>
            <span>WINNING HAND</span>
            <span class="text-right">REPLAY</span>
          </div>

          <%= if Enum.empty?(@hands) do %>
            <div class="px-6 py-16 text-center">
              <p class="text-[var(--pkr-ink-3)] font-medium">No hands found</p>
              <p class="text-sm text-[var(--pkr-ink-3)]/70 mt-1">
                Play some hands to see your history here.
              </p>
            </div>
          <% else %>
            <%= for {hand, index} <- Enum.with_index(@hands) do %>
              <div class={"grid grid-cols-[1.4fr_0.6fr_0.7fr_0.7fr_1.2fr_0.6fr] px-4 py-3 items-center text-[13px] " <>
                if(index < length(@hands) - 1, do: "border-b border-dashed border-[var(--pkr-line)]", else: "")}>
                <!-- Date -->
                <span class="font-[family-name:var(--pkr-font-mono)] text-[12px] text-[var(--pkr-ink-2)]">
                  {format_date(hand.inserted_at)}
                </span>
                <!-- Lobby -->
                <.link
                  navigate={lobby_path(hand)}
                  class="font-[family-name:var(--pkr-font-mono)] text-[12px] text-[var(--pkr-ink-2)] hover:text-[var(--pkr-accent)] transition-colors"
                >
                  {format_game_mode(hand.game_mode)}
                </.link>
                <!-- Pot -->
                <span class="font-[family-name:var(--pkr-font-mono)] text-[12px] text-[var(--pkr-ink-2)]">
                  ${hand.pot_total}
                </span>
                <!-- Result -->
                <span class={"font-[family-name:var(--pkr-font-mono)] text-[12px] font-semibold " <> result_class(hand.amount_won, hand.amount_invested)}>
                  {format_result(hand.amount_won, hand.amount_invested)}
                </span>
                <!-- Winning hand -->
                <div>
                  <span class="text-[12px] text-[var(--pkr-ink-2)]">
                    {hand.winner_hand_rank || "—"}
                  </span>
                  <span class="text-[11px] text-[var(--pkr-ink-3)] ml-1">
                    {format_finish_reason(hand.finish_reason)}
                  </span>
                </div>
                <!-- Replay -->
                <div class="text-right">
                  <.link
                    navigate={replay_path(hand)}
                    class="px-2.5 py-1 rounded-md text-[11px] font-[family-name:var(--pkr-font-mono)] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] hover:bg-[var(--pkr-bg-2)] transition-all"
                  >
                    Replay
                  </.link>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- Load more -->
        <%= if @next_cursor do %>
          <div class="mt-4 flex justify-center">
            <button
              phx-click="load_more"
              class="px-4 py-2 rounded-lg text-[13px] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] bg-[var(--pkr-bg-1)] hover:bg-[var(--pkr-bg-2)] transition-all cursor-pointer font-[family-name:var(--pkr-font-mono)]"
            >
              Load more
            </button>
          </div>
        <% end %>
      </main>
    </div>
    """
  end
end
