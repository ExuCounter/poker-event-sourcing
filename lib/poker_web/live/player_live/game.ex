defmodule PokerWeb.PlayerLive.Game do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables
  alias PokerWeb.Api.CashGames
  alias PokerWeb.JsonEncoder

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    lobby = Tables.get_lobby(socket.assigns.current_scope, table_id)

    if is_nil(lobby) do
      {:ok,
       socket
       |> put_flash(:error, "Table not found")
       |> push_navigate(to: ~p"/")}
    else
      {:ok, game_context} = build_game_context(table_id)

      game_view =
        Tables.get_player_game_view(socket.assigns.current_scope, table_id,
          game_context: game_context
        )

      socket =
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")

          if game_context && game_context.type == :tournament do
            Poker.Tournaments.PubSub.subscribe_to_tournament(game_context.tournament_id)
          end

          socket
        else
          socket
        end

      buy_in_amount =
        case game_view.player_actions.can_buy_in do
          %{max: max} -> max
          false -> 0
        end

      lobby_path = lobby_path(game_context, table_id)

      {:ok,
       assign(socket,
         table_id: table_id,
         lobby_path: lobby_path,
         game_view: game_view,
         game_context: game_context,
         current_user_id: socket.assigns.current_scope.user.id,
         show_buy_in: false,
         buy_in_amount: buy_in_amount,
         raise_amount: nil,
         current_animated_event_id: nil,
         queue: []
       )}
    end
  end

  @impl true
  def handle_info({:tournament, _event, _data}, socket) do
    case build_game_context(socket.assigns.table_id) do
      {:ok, game_context} -> {:noreply, assign(socket, game_context: game_context)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:table, _event, data}, socket) do
    data = Map.put(data, :received_at, System.monotonic_time(:millisecond))
    socket = assign(socket, queue: socket.assigns.queue ++ [data])

    if is_nil(socket.assigns.current_animated_event_id) do
      socket = process_next_event(socket)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("event_processed", %{"streamVersion" => processed_stream_version}, socket) do
    remaining_queue =
      Enum.reject(socket.assigns.queue, fn event ->
        event.stream_version == processed_stream_version
      end)

    game_context = socket.assigns.game_context

    game_view =
      Tables.get_player_game_view(
        socket.assigns.current_scope,
        socket.assigns.table_id,
        since_version: processed_stream_version,
        game_context: game_context
      )

    # Always use the latest player_actions (not the animated version)
    latest_game_view =
      Tables.get_player_game_view(socket.assigns.current_scope, socket.assigns.table_id,
        game_context: game_context
      )

    socket =
      assign(socket,
        queue: remaining_queue,
        game_view: %{game_view | player_actions: latest_game_view.player_actions}
      )

    socket = process_next_event(socket)

    {:noreply, socket}
  end

  # Action event handlers
  @impl true
  def handle_event("fold_hand", _params, socket) do
    Tables.fold_hand(socket.assigns.current_scope, socket.assigns.table_id)
    |> handle_action_result(socket)
  end

  def handle_event("check_hand", _params, socket) do
    Tables.check_hand(socket.assigns.current_scope, socket.assigns.table_id)
    |> handle_action_result(socket)
  end

  def handle_event("call_hand", _params, socket) do
    Tables.call_hand(socket.assigns.current_scope, socket.assigns.table_id)
    |> handle_action_result(socket)
  end

  def handle_event("raise_hand", %{"amount" => amount}, socket) do
    case Integer.parse(amount) do
      {amount_int, _} ->
        Tables.raise_hand(socket.assigns.current_scope, socket.assigns.table_id, amount_int)
        |> handle_action_result(socket)

      :error ->
        {:noreply, put_flash(socket, :error, "Invalid raise amount")}
    end
  end

  def handle_event("all_in_hand", _params, socket) do
    Tables.all_in_hand(socket.assigns.current_scope, socket.assigns.table_id)
    |> handle_action_result(socket)
  end

  def handle_event("update_raise_amount", %{"raise_amount" => amount}, socket) do
    case Integer.parse(amount) do
      {amount_int, _} ->
        {:noreply, assign(socket, raise_amount: amount_int)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("sit_out", _params, socket) do
    case Tables.sit_out_participant(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, refresh_player_actions(socket)}
      {:ok, _} -> {:noreply, refresh_player_actions(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("sit_in", _params, socket) do
    case Tables.sit_in_participant(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok -> {:noreply, maybe_rebuild_or_refresh(socket)}
      {:ok, _} -> {:noreply, maybe_rebuild_or_refresh(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("show_buy_in", _params, socket) do
    buy_in_amount =
      case socket.assigns.game_view.player_actions.can_buy_in do
        %{max: max} -> max
        false -> 0
      end

    {:noreply, assign(socket, show_buy_in: true, buy_in_amount: buy_in_amount)}
  end

  def handle_event("close_buy_in", _params, socket) do
    {:noreply, assign(socket, show_buy_in: false)}
  end

  def handle_event("update_buy_in_amount", %{"amount" => amount}, socket) do
    case Integer.parse(amount) do
      {amount_int, _} -> {:noreply, assign(socket, buy_in_amount: amount_int)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event(
        "confirm_buy_in",
        _params,
        %{assigns: %{game_context: %{cash_game: cash_game}}} = socket
      ) do
    case CashGames.buy_in(
           socket.assigns.current_scope,
           cash_game.id,
           socket.assigns.buy_in_amount
         ) do
      :ok ->
        socket = socket |> assign(show_buy_in: false) |> refresh_player_actions()
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("leave_table", _params, socket) do
    case Tables.leave_table(socket.assigns.current_scope, socket.assigns.table_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "You have left the table")
         |> push_navigate(to: socket.assigns.lobby_path)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def handle_event("join_at_seat", %{"seat_number" => seat_number}, socket) do
    case Tables.join_participant(socket.assigns.current_scope, %{
           table_id: socket.assigns.table_id,
           seat_number: seat_number
         }) do
      {:ok, _participant_id} ->
        # Refresh game view after joining
        game_view =
          Tables.get_player_game_view(socket.assigns.current_scope, socket.assigns.table_id,
            game_context: socket.assigns.game_context
          )

        socket =
          socket
          |> assign(game_view: game_view)
          |> push_event("rebuild_state", %{state: JsonEncoder.transform_keys(game_view)})

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  # Errors that should be silently ignored (double-clicks, stale UI state)
  @silent_errors [
    :not_your_turn,
    :not_participants_turn,
    :no_active_hand,
    :already_folded,
    :stale_timeout,
    :already_sat_out,
    :not_sitting_out
  ]

  defp handle_action_result(:ok, socket), do: {:noreply, socket}

  defp handle_action_result({:error, reason}, socket) when reason in @silent_errors,
    do: {:noreply, socket}

  defp handle_action_result({:error, %{status: status}}, socket) when status in @silent_errors,
    do: {:noreply, socket}

  defp handle_action_result({:error, reason}, socket),
    do: {:noreply, put_flash(socket, :error, format_error(reason))}

  # Dynamic timing based on event age
  # {min_age_ms, multiplier} - :skip means instant jump

  @speed_thresholds [
    {12_500, 0.2},
    {10_000, 0.5},
    {7_500, 0.8}
  ]

  defp maybe_rebuild_or_refresh(socket) do
    queue_has_other_hand = Enum.any?(socket.assigns.queue, &(&1.type == "HandStarted"))

    if queue_has_other_hand do
      flush_and_rebuild(socket)
    else
      socket
    end
  end

  defp flush_and_rebuild(socket) do
    game_context =
      case build_game_context(socket.assigns.table_id) do
        {:ok, ctx} -> ctx
        _ -> socket.assigns.game_context
      end

    game_view =
      Tables.get_player_game_view(socket.assigns.current_scope, socket.assigns.table_id,
        game_context: game_context
      )

    buy_in_amount =
      case game_view.player_actions.can_buy_in do
        %{max: max} -> max
        false -> 0
      end

    socket
    |> assign(
      queue: [],
      current_animated_event_id: nil,
      game_view: game_view,
      game_context: game_context,
      buy_in_amount: buy_in_amount,
      raise_amount: nil,
      show_buy_in: false
    )
    |> push_event("rebuild_state", %{state: JsonEncoder.transform_keys(game_view)})
  end

  defp process_next_event(socket) do
    case socket.assigns.queue do
      [] ->
        assign(socket, current_animated_event_id: nil)

      [next_event | _rest] ->
        game_view =
          Tables.get_player_game_view(
            socket.assigns.current_scope,
            socket.assigns.table_id,
            since_version: next_event.stream_version,
            game_context: socket.assigns.game_context
          )

        adjusted_event = apply_dynamic_timing(next_event)

        socket =
          push_event(socket, "table_event", %{
            event: JsonEncoder.transform_keys(adjusted_event),
            new_state: JsonEncoder.transform_keys(game_view)
          })

        assign(socket,
          current_animated_event_id: next_event.event_id,
          raise_amount: nil
        )
    end
  end

  defp apply_dynamic_timing(%{timing: timing} = event) when is_map(timing) do
    age_ms = System.monotonic_time(:millisecond) - event.received_at
    multiplier = get_speed_multiplier(age_ms)

    event
    |> update_in([:timing, :duration], &round(&1 * multiplier))
    |> maybe_update_in([:timing, :stagger], &round(&1 * multiplier))
  end

  defp apply_dynamic_timing(event), do: event

  defp maybe_update_in(map, path, fun) do
    if get_in(map, path), do: update_in(map, path, fun), else: map
  end

  defp get_speed_multiplier(age_ms) do
    Enum.find_value(@speed_thresholds, 1.0, fn {threshold, multiplier} ->
      if age_ms >= threshold, do: multiplier
    end)
  end

  # Helper functions
  defp format_error(%{message: message}), do: message
  defp format_error(reason) when is_binary(reason), do: reason

  defp format_error(reason) when is_atom(reason) do
    case reason do
      :no_active_hand -> "No active hand in progress"
      :not_your_turn -> "It's not your turn to act"
      :participant_not_found -> "You are not a participant at this table"
      :insufficient_chips -> "Not enough chips for this action"
      :already_folded -> "You have already folded"
      :already_sat_out -> "You are already sitting out"
      :table_not_started -> "The table has not started yet"
      :table_finished -> "The table has finished"
      :table_already_finished -> "The table has already finished"
      :stale_timeout -> "Action already processed"
      :not_table_owner -> "Only the table owner can perform this action"
      :not_enough_participants -> "Not enough participants to start"
      :table_already_started -> "The table has already started"
      :cannot_leave_tournament -> "Cannot leave a tournament"
      :seat_occupied -> "This seat is already taken"
      :already_joined -> "You have already joined this table"
      _ -> "Action failed: #{reason}"
    end
  end

  defp format_error(reason), do: "Action failed: #{inspect(reason)}"

  defp refresh_player_actions(socket) do
    game_view =
      Tables.get_player_game_view(socket.assigns.current_scope, socket.assigns.table_id,
        game_context: socket.assigns.game_context
      )

    assign(socket,
      game_view: %{socket.assigns.game_view | player_actions: game_view.player_actions}
    )
  end

  defp lobby_path(%{type: :tournament, tournament_id: tid}, _table_id),
    do: ~p"/tournaments/#{tid}/lobby"

  defp lobby_path(_game_context, table_id), do: ~p"/cash/#{table_id}/lobby"

  defp build_game_context(table_id) do
    case Poker.Repo.get(Poker.Tables.Projections.TableLobby, table_id) do
      %{game_mode: :cash_game} ->
        with {:ok, cash_game} <- Poker.CashGames.get_cash_game_by_table(table_id) do
          {:ok,
           %{
             type: :cash_game,
             cash_game: cash_game,
             min_buyin: cash_game.min_buyin,
             max_buyin: cash_game.max_buyin
           }}
        end

      %{game_mode: :tournament, source_id: tournament_id} when is_binary(tournament_id) ->
        with {:ok, tournament} <- Poker.Tournaments.get_tournament(tournament_id) do
          blind = Poker.Tournaments.BlindStructure.get_level(tournament.current_level)
          level_duration = Poker.Tournaments.BlindStructure.duration_seconds(tournament.speed)
          prize_pool = tournament.buy_in * tournament.max_players

          payouts =
            Poker.Tournaments.BlindStructure.calculate_payouts(
              tournament.max_players,
              tournament.buy_in
            )

          {:ok,
           %{
             type: :tournament,
             tournament_id: tournament_id,
             speed: tournament.speed,
             buy_in: tournament.buy_in,
             players_remaining: tournament.players_remaining,
             total_players: tournament.max_players,
             current_level: tournament.current_level,
             small_blind: blind.small_blind,
             big_blind: blind.big_blind,
             level_duration: level_duration,
             level_started_at: tournament.level_started_at,
             prize_pool: prize_pool,
             payouts: payouts
           }}
        end

      _ ->
        {:ok, nil}
    end
  end

  @impl true
  def render(assigns) do
    # Initialize raise_amount from game_view if not set
    assigns =
      if is_nil(assigns.raise_amount) && assigns.game_view.valid_actions.raise do
        assign(assigns, raise_amount: assigns.game_view.valid_actions.raise.min)
      else
        assigns
      end

    ~H"""
    <div style="height: 100vh; position: relative; overflow: hidden;">
      <div
        class="absolute top-4 left-1/2 z-50"
        style="transform: translateX(-50%) scale(var(--ui-scale, 1)); transform-origin: top center;"
      >
        <.flash kind={:error} flash={@flash} />
        <.flash kind={:info} flash={@flash} />
      </div>
      <canvas
        id="poker-canvas"
        phx-hook="PokerCanvas"
        phx-update="ignore"
        data-state={JsonEncoder.transform_keys(@game_view) |> Jason.encode!()}
        data-current-user-id={@current_user_id}
      />
      
    <!-- Tournament HUD (scaled with ui-scale, top-right) -->
      <%= if @game_context && @game_context.type == :tournament do %>
        <div class="absolute top-0 right-0 z-10" style="transform-origin: top right;">
          <div style="transform: scale(var(--ui-scale, 1)); transform-origin: top right; width: calc(100vw / var(--ui-scale, 1));">
            <div class="absolute top-17 right-5 text-right">
              <div class="flex flex-col gap-1.5 items-end">
                <!-- Blinds -->
                <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[var(--pkr-line)] bg-black/60 backdrop-blur-lg font-[family-name:var(--pkr-font-mono)]">
                  <span class="text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                    LVL {@game_context.current_level}
                  </span>
                  <span class="text-[13px] font-semibold text-[var(--pkr-ink-1)]">
                    {@game_context.small_blind}/{@game_context.big_blind}
                  </span>
                  <%= if @game_context.level_started_at do %>
                    <span class="text-[var(--pkr-line)]">&middot;</span>
                    <span
                      id="blind-countdown"
                      phx-hook="BlindCountdown"
                      data-level-started-at={DateTime.to_iso8601(@game_context.level_started_at)}
                      data-level-duration={@game_context.level_duration}
                      class="text-[13px] font-medium text-[var(--pkr-accent)]"
                    />
                  <% end %>
                </div>
                <!-- Players / Position -->
                <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[var(--pkr-line)] bg-black/60 backdrop-blur-lg font-[family-name:var(--pkr-font-mono)] text-[12px]">
                  <span class="text-[var(--pkr-ink-3)]">Sit &amp; Go</span>
                  <span class="text-[var(--pkr-line)]">&middot;</span>
                  <span class="text-[var(--pkr-ink-2)]">
                    {@game_context.players_remaining}/{@game_context.total_players}
                  </span>
                  <%= if @game_view.tournament_position do %>
                    <span class="text-[var(--pkr-line)]">&middot;</span>
                    <span class="font-semibold text-[var(--pkr-ink-1)]">
                      #{@game_view.tournament_position}
                    </span>
                    <%= if @game_view.current_payout do %>
                      <span class="text-[var(--pkr-positive)] font-medium">
                        (+{@game_view.current_payout})
                      </span>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div style="transform: scale(var(--ui-scale, 1)); transform-origin: bottom left; width: calc(100vw / var(--ui-scale, 1));">
        <!-- Sit Out/In/Buy In Button - bottom-left corner -->
        <%= if @game_view.player_actions.is_participant do %>
          <div class="absolute left-5 bottom-5 z-10 flex items-center">
            <!-- Buy In button (cash games) -->
            <%= if @game_view.player_actions.can_buy_in != false or @game_view.game_mode == :cash_game do %>
              <% can_buy_in = @game_view.player_actions.can_buy_in != false %>
              <div class="relative group">
                <button
                  phx-click={if can_buy_in, do: "show_buy_in"}
                  disabled={!can_buy_in}
                  class={[
                    "px-3.5 py-1.5 rounded-lg font-medium text-[13px] border backdrop-blur-lg transition-all mr-3 font-[family-name:var(--pkr-font-ui)]",
                    if(can_buy_in,
                      do:
                        "bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] border-[var(--pkr-accent)] hover:brightness-110 cursor-pointer",
                      else:
                        "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-3)] border-[var(--pkr-line)] opacity-60 cursor-not-allowed"
                    )
                  ]}
                >
                  Buy In
                </button>
                <%= unless can_buy_in do %>
                  <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-1.5 bg-[var(--pkr-bg-1)] text-[var(--pkr-ink-3)] text-[11px] rounded-md whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none border border-[var(--pkr-line)] font-[family-name:var(--pkr-font-mono)]">
                    Max chips reached
                  </div>
                <% end %>
              </div>
            <% end %>
            
    <!-- Sit Out / Sit In button -->
            <%= if @game_view.player_actions.can_sit_out do %>
              <button
                phx-click="sit_out"
                class="px-3.5 py-1.5 rounded-lg font-medium text-[13px] border border-[var(--pkr-line)] bg-black/50 text-[var(--pkr-ink-2)] hover:bg-[var(--pkr-bg-2)] hover:text-[var(--pkr-ink-1)] backdrop-blur-lg transition-all cursor-pointer font-[family-name:var(--pkr-font-ui)]"
              >
                Sit Out
              </button>
            <% end %>
            <%= if @game_view.player_actions.can_sit_in do %>
              <button
                phx-click="sit_in"
                class="px-3.5 py-1.5 rounded-lg font-medium text-[13px] border border-[var(--pkr-positive)] bg-[var(--pkr-positive)] text-[var(--pkr-bg-0)] hover:brightness-110 backdrop-blur-lg transition-all cursor-pointer font-[family-name:var(--pkr-font-ui)]"
              >
                Sit In
              </button>
            <% end %>

            <%= if @game_view.my_hand_rank do %>
              <div class="px-2.5 py-1 rounded-md font-[family-name:var(--pkr-font-mono)] text-xs font-semibold text-[var(--pkr-accent)] tracking-wide">
                {@game_view.my_hand_rank.display_name}
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Action Controls - positioned and scaled -->
        <div class="absolute bottom-[16px] right-[16px]">
          <%= if Enum.any?(@game_view.valid_actions, fn {_key, value} -> value end) and is_nil(@current_animated_event_id) do %>
            <div class="flex flex-col gap-2 p-2.5 rounded-xl border border-[var(--pkr-line)] bg-black/80 backdrop-blur-lg shadow-2xl w-[260px] font-[family-name:var(--pkr-font-ui)]">
              <!-- Raise Controls -->
              <%= if @game_view.valid_actions.raise do %>
                <div class="flex flex-col gap-1 p-2 rounded-lg border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)]">
                  <div class="flex items-baseline justify-between mb-1">
                    <span class="font-[family-name:var(--pkr-font-mono)] text-[9px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)]">
                      RAISE TO
                    </span>
                    <span class="font-[family-name:var(--pkr-font-display)] text-[22px] leading-none text-[var(--pkr-ink-1)] tracking-tight">
                      ${@raise_amount}
                    </span>
                  </div>
                  <form phx-change="update_raise_amount">
                    <input
                      type="range"
                      name="raise_amount"
                      min={@game_view.valid_actions.raise.min}
                      max={@game_view.valid_actions.raise.max}
                      value={@raise_amount}
                      class="w-full h-1 rounded cursor-pointer accent-[var(--pkr-accent)]"
                    />
                  </form>
                  <div class="flex gap-1 mt-1">
                    <%= for preset <- @game_view.valid_actions.raise.presets do %>
                      <button
                        type="button"
                        phx-click="update_raise_amount"
                        phx-value-raise_amount={preset.value}
                        class="flex-1 py-1 rounded-md text-[11px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] hover:bg-[var(--pkr-bg-1)] hover:text-[var(--pkr-ink-1)] cursor-pointer font-[family-name:var(--pkr-font-mono)] transition-all"
                      >
                        {preset.label}
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
              
    <!-- 3-up action row -->
              <div class="grid grid-cols-3 gap-1.5">
                <%= if @game_view.valid_actions.fold do %>
                  <button
                    phx-click="fold_hand"
                    class="inline-flex items-center justify-center py-2.5 px-3 rounded-lg text-[13px] font-semibold tracking-wide border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] bg-transparent hover:bg-[var(--pkr-danger)]/15 hover:text-[var(--pkr-danger)] cursor-pointer transition-all"
                  >
                    Fold
                  </button>
                <% end %>
                <%= if @game_view.valid_actions.check do %>
                  <button
                    phx-click="check_hand"
                    class="inline-flex items-center justify-center py-2.5 px-3 rounded-lg text-[13px] font-semibold tracking-wide border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] bg-[var(--pkr-bg-2)] hover:bg-[var(--pkr-bg-1)] cursor-pointer transition-all"
                  >
                    Check
                  </button>
                <% end %>
                <%= if @game_view.valid_actions.call do %>
                  <button
                    phx-click="call_hand"
                    class="inline-flex items-center justify-center gap-1 py-2.5 px-3 rounded-lg text-[13px] font-semibold tracking-wide border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] bg-[var(--pkr-bg-2)] hover:bg-[var(--pkr-bg-1)] cursor-pointer transition-all"
                  >
                    <span>Call</span>
                    <span class="font-[family-name:var(--pkr-font-mono)] text-[10px] opacity-70">
                      ${@game_view.valid_actions.call.amount}
                    </span>
                  </button>
                <% end %>
                <%= if @game_view.valid_actions.raise do %>
                  <button
                    phx-click="raise_hand"
                    phx-value-amount={@raise_amount}
                    class="inline-flex items-center justify-center py-2.5 px-3 rounded-lg text-[13px] font-semibold tracking-wide border border-[var(--pkr-accent)] text-[var(--pkr-bg-0)] bg-[var(--pkr-accent)] hover:brightness-110 cursor-pointer transition-all shadow-[0_6px_16px_color-mix(in_oklch,var(--pkr-accent),transparent_70%)]"
                  >
                    Raise
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>

          <div
            id="connection-status"
            phx-disconnected={JS.show()}
            phx-connected={JS.hide()}
            class="hidden absolute top-4 left-1/2 -translate-x-1/2 bg-yellow-600 text-white px-4 py-2 rounded-lg"
          >
            ⚠️ Disconnected - trying to reconnect...
          </div>
        </div>
      </div>
      
    <!-- Buy In Modal (outside scaled container) -->
      <%= if @show_buy_in && @game_view.player_actions.can_buy_in do %>
        <% buy_in = @game_view.player_actions.can_buy_in %>
        <div class="absolute inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
          <div class="bg-[var(--pkr-bg-1)] rounded-xl p-6 shadow-2xl border border-[var(--pkr-line)] w-80 font-[family-name:var(--pkr-font-ui)]">
            <h3 class="font-[family-name:var(--pkr-font-display)] text-xl text-[var(--pkr-ink-1)] mb-4 tracking-tight">
              Buy In
            </h3>

            <div class="mb-4">
              <div class="text-center font-[family-name:var(--pkr-font-display)] text-[32px] text-[var(--pkr-accent)] mb-3 tracking-tight">
                ${@buy_in_amount}
              </div>
              <form phx-change="update_buy_in_amount">
                <input
                  type="range"
                  name="amount"
                  min={buy_in.min}
                  max={buy_in.max}
                  value={@buy_in_amount}
                  class="w-full h-1 rounded cursor-pointer accent-[var(--pkr-accent)]"
                />
              </form>
              <div class="flex justify-between font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)] mt-1">
                <span>${buy_in.min}</span>
                <span>${buy_in.max}</span>
              </div>
            </div>

            <div class="flex gap-3">
              <button
                phx-click="close_buy_in"
                class="flex-1 px-4 py-2.5 rounded-lg font-medium text-[13px] bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-2)] border border-[var(--pkr-line)] hover:bg-[var(--pkr-bg-0)] transition-all cursor-pointer"
              >
                Cancel
              </button>
              <button
                phx-click="confirm_buy_in"
                class="flex-1 px-4 py-2.5 rounded-lg font-medium text-[13px] bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] border border-[var(--pkr-accent)] hover:brightness-110 transition-all cursor-pointer"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def normalized_table_type(:six_max), do: "6-max"
end
