defmodule PokerWeb.PlayerLive.Lobby do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    with lobby when not is_nil(lobby) <- Tables.get_lobby(socket.assigns.current_scope, table_id),
         {:ok, cash_game} <- Poker.CashGames.get_cash_game_by_table(table_id) do
      if connected?(socket) do
        Poker.Tables.PubSub.subscribe_to_lobby(table_id)
      end

      {:ok,
       assign(socket,
         lobby: lobby,
         cash_game: cash_game,
         table_id: table_id,
         user_id: socket.assigns.current_scope.user.id
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Table not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("join_table", %{"seat_number" => seat_number}, socket) do
    seat_number = String.to_integer(seat_number)

    case Tables.join_participant(socket.assigns.current_scope, %{
           table_id: socket.assigns.table_id,
           seat_number: seat_number
         }) do
      {:ok, _participant_id} ->
        {:noreply, push_navigate(socket, to: ~p"/tables/#{socket.assigns.table_id}/game")}

      {:error, %{message: message}} ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join table: #{inspect(reason)}")}
    end
  end

  def handle_event("join_table", _params, socket) do
    case Tables.join_participant(socket.assigns.current_scope, %{
           table_id: socket.assigns.table_id
         }) do
      {:ok, _participant_id} ->
        {:noreply, push_navigate(socket, to: ~p"/tables/#{socket.assigns.table_id}/game")}

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
    {:noreply,
     assign(socket,
       lobby: Tables.get_lobby(socket.assigns.current_scope, socket.assigns.table_id)
     )}
  end

  defp user_has_joined?(participants, user_id) do
    Enum.any?(participants, fn p -> p.player_id == user_id end)
  end

  defp seats_total(:two_max), do: 2
  defp seats_total(:three_max), do: 3
  defp seats_total(:four_max), do: 4
  defp seats_total(:six_max), do: 6
  defp seats_total(_), do: 6

  defp seat_positions(total) do
    for i <- 0..(total - 1) do
      angle = i / total * :math.pi() * 2 - :math.pi() / 2
      x = 50 + :math.cos(angle) * 42
      y = 50 + :math.sin(angle) * 42
      %{index: i, x: x, y: y}
    end
  end

  defp participant_at_seat(participants, seat_number) do
    Enum.find(participants, fn p -> p.seat_number == seat_number end)
  end

  defp format_table_type(:two_max), do: "HU"
  defp format_table_type(:three_max), do: "3-max"
  defp format_table_type(:four_max), do: "4-max"
  defp format_table_type(:six_max), do: "6-max"
  defp format_table_type(_), do: "—"

  @impl true
  def render(assigns) do
    total = seats_total(assigns.cash_game.table_type)
    positions = seat_positions(total)
    assigns = assign(assigns, total_seats: total, seat_positions: positions)

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
        <.share_code_chip :if={@cash_game.code} code={@cash_game.code} class="mr-2" />
        <span class="px-2.5 py-1 rounded-full text-xs border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-2)] font-[family-name:var(--pkr-font-mono)]">
          ${@cash_game.small_blind}/${@cash_game.big_blind}
        </span>
        <span class="ml-2 px-2.5 py-1 rounded-full text-xs border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-2)] font-[family-name:var(--pkr-font-mono)]">
          NLHE &middot; {format_table_type(@cash_game.table_type)}
        </span>
      </div>

      <.flash kind={:error} flash={@flash} />
      <.flash kind={:info} flash={@flash} />

      <div class="flex flex-1 min-h-0">
        <!-- Left: Table preview -->
        <div class="flex-1 flex items-center justify-center p-8">
          <div class="w-[620px] h-[360px] relative">
            <!-- Felt oval -->
            <div
              class="absolute inset-0 rounded-[50%]"
              style="background: linear-gradient(180deg, oklch(20% 0.03 28), oklch(12% 0.02 28)); box-shadow: 0 40px 80px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.05)"
            >
            </div>
            <div
              class="absolute inset-4 rounded-[50%]"
              style="background: radial-gradient(ellipse at center, oklch(38% 0.08 160) 0%, oklch(28% 0.06 160) 55%, oklch(20% 0.04 160) 100%); box-shadow: inset 0 0 0 1px oklch(76% 0.13 85 / 0.3), inset 0 4px 24px rgba(0,0,0,0.5)"
            >
            </div>
            <div class="absolute inset-[26px] rounded-[50%] border border-[var(--pkr-accent)]/20">
            </div>
            
    <!-- Center status -->
            <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-center z-10">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2">
                {if @lobby.status == :waiting,
                  do: "WAITING TO START",
                  else: String.upcase(to_string(@lobby.status))}
              </div>
              <div class="font-[family-name:var(--pkr-font-display)] text-[28px] leading-tight text-[var(--pkr-ink-1)]">
                {@lobby.seated_count} of {@lobby.seats_count} seated
              </div>
              <div class="font-[family-name:var(--pkr-font-mono)] text-xs text-[var(--pkr-ink-3)] mt-2">
                Need 2 to start
              </div>
            </div>
            
    <!-- Seat dots -->
            <%= for pos <- @seat_positions do %>
              <% participant = participant_at_seat(@lobby.participants, pos.index + 1) %>
              <div
                class="absolute z-10"
                style={"left: #{pos.x}%; top: #{pos.y}%; transform: translate(-50%, -50%)"}
              >
                <%= if participant do %>
                  <div class={"flex items-center gap-2 px-2.5 py-1.5 rounded-full backdrop-blur-md bg-black/60 " <>
                    if(participant.player_id == @user_id, do: "border-[1.5px] border-[var(--pkr-accent)]", else: "border border-[var(--pkr-line)]")}>
                    <div class="w-6 h-6 rounded-full bg-[var(--pkr-bg-2)] flex items-center justify-center text-[10px] font-semibold text-[var(--pkr-ink-2)]">
                      {String.first(participant.nickname || participant.email) |> String.upcase()}
                    </div>
                    <div class="text-xs leading-tight">
                      <div class="text-[var(--pkr-ink-1)]">
                        {participant.nickname || String.split(participant.email, "@") |> hd()}
                      </div>
                    </div>
                  </div>
                <% else %>
                  <%= if not user_has_joined?(@lobby.participants, @user_id) and @lobby.seated_count < @lobby.seats_count do %>
                    <button
                      phx-click="join_table"
                      phx-value-seat_number={pos.index + 1}
                      class="px-3 py-1.5 rounded-full text-[11px] bg-transparent border border-dashed border-[var(--pkr-accent)]/50 text-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)] tracking-wider hover:bg-[var(--pkr-accent)]/10 transition-all cursor-pointer"
                    >
                      + SEAT {pos.index + 1}
                    </button>
                  <% else %>
                    <div class="w-3 h-3 rounded-full bg-[var(--pkr-line)]/50"></div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Right rail -->
        <aside class="w-[360px] border-l border-[var(--pkr-line)] p-5 flex flex-col gap-3.5 overflow-auto">
          <div>
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
              TABLE
            </div>
            <h2 class="font-[family-name:var(--pkr-font-display)] text-[28px] leading-none text-[var(--pkr-ink-1)]">
              NL Hold'em
            </h2>
            <div class="font-[family-name:var(--pkr-font-mono)] text-xs text-[var(--pkr-ink-3)] mt-1">
              {format_table_type(@cash_game.table_type)} &middot; ${@cash_game.small_blind}/${@cash_game.big_blind}
            </div>
          </div>
          
    <!-- Rules -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)] mb-2.5">
              RULES
            </div>
            <div class="space-y-0">
              <.stat_row label="Game" value="No-Limit Hold'em" />
              <.stat_row
                label="Stakes"
                value={"$#{@cash_game.small_blind} / $#{@cash_game.big_blind}"}
              />
              <.stat_row label="Buy-in" value={"$#{@cash_game.min_buyin} – $#{@cash_game.max_buyin}"} />
              <.stat_row label="Seats" value={"#{@lobby.seated_count} / #{@lobby.seats_count}"} />
            </div>
          </div>
          
    <!-- Players -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] p-3.5">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)] mb-2.5">
              PLAYERS ({@lobby.seated_count})
            </div>
            <%= if Enum.empty?(@lobby.participants) do %>
              <div class="text-sm text-[var(--pkr-ink-3)] text-center py-4">Waiting for players</div>
            <% else %>
              <div class="space-y-1.5">
                <%= for participant <- @lobby.participants do %>
                  <div class="flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg bg-[var(--pkr-bg-2)]/50">
                    <div class="w-7 h-7 rounded-full bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] flex items-center justify-center text-[10px] font-semibold text-[var(--pkr-ink-2)]">
                      {String.first(participant.nickname || participant.email) |> String.upcase()}
                    </div>
                    <span class="text-[13px] text-[var(--pkr-ink-1)] truncate flex-1">
                      {participant.nickname || String.split(participant.email, "@") |> hd()}
                    </span>
                    <div class="w-1.5 h-1.5 rounded-full bg-[var(--pkr-positive)]"></div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="flex-1"></div>
          
    <!-- Actions -->
          <%= cond do %>
            <% user_has_joined?(@lobby.participants, @user_id) -> %>
              <.link
                navigate={~p"/tables/#{@lobby.id}/game"}
                class="block w-full text-center py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all"
              >
                Enter Game
              </.link>
            <% @lobby.seated_count < @lobby.seats_count -> %>
              <button
                phx-click="join_table"
                class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
              >
                Take seat &amp; join
              </button>
            <% true -> %>
              <div class="w-full py-3 rounded-xl text-sm text-center text-[var(--pkr-ink-3)] border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)]">
                Table full ({@lobby.seats_count} max)
              </div>
          <% end %>

          <.link
            navigate={~p"/tables/#{@lobby.id}/game"}
            class="block w-full text-center py-3 rounded-xl text-[13px] text-[var(--pkr-ink-2)] border border-[var(--pkr-line)] hover:bg-[var(--pkr-bg-2)] transition-all"
          >
            Watch from rail
          </.link>

          <%= if @lobby.status in [:waiting, :live] && @lobby.seated_count >= 2 && @cash_game.creator_id == @user_id do %>
            <button
              phx-click="start_table"
              class="w-full py-3 rounded-xl text-[13px] font-medium text-[var(--pkr-positive)] border border-[var(--pkr-positive)]/40 hover:bg-[var(--pkr-positive)]/10 transition-all cursor-pointer"
            >
              Start Game
            </button>
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
