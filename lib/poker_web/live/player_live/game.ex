defmodule PokerWeb.PlayerLive.Game do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables
  alias PokerWeb.Api.CashGames
  alias PokerWeb.JsonEncoder

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    lobby = Tables.get_lobby(table_id)

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

  defp apply_dynamic_timing(event) do
    age_ms = System.monotonic_time(:millisecond) - event.received_at
    multiplier = get_speed_multiplier(age_ms)

    event
    |> update_in([:timing, :duration], &round(&1 * multiplier))
    |> maybe_update_in([:timing, :stagger], &round(&1 * multiplier))
  end

  defp maybe_update_in(map, path, fun) do
    if get_in(map, path), do: update_in(map, path, fun), else: map
  end

  defp maybe_put_in(map, path, value) do
    if get_in(map, path), do: put_in(map, path, value), else: map
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
    case Poker.Repo.get(Poker.Tables.Projections.TableList, table_id) do
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
      
    <!-- Tournament HUD (outside scaled container) -->
      <%= if @game_context && @game_context.type == :tournament do %>
        <div class="absolute top-14 right-5 z-10 text-right leading-snug">
          <div class="text-xs text-gray-400">
            Blinds level: {@game_context.current_level}
            <span class="text-white font-medium">
              {@game_context.small_blind}/{@game_context.big_blind}
            </span>
            <%= if @game_context.level_started_at do %>
              <span class="text-gray-500">·</span>
              <span
                id="blind-countdown"
                phx-hook="BlindCountdown"
                data-level-started-at={DateTime.to_iso8601(@game_context.level_started_at)}
                data-level-duration={@game_context.level_duration}
                class="text-amber-400 font-mono font-medium"
              />
            <% end %>
          </div>
          <%= if @game_view.tournament_position do %>
            <div class="text-xs text-gray-400">
              Sit & Go <span class="text-gray-500">·</span>
              {@game_context.players_remaining}/{@game_context.total_players} players
              <span class="text-gray-500">·</span>
              <span class="text-white font-medium">
                {@game_view.tournament_position}/{@game_context.players_remaining}
              </span>
              <%= if @game_view.current_payout do %>
                <span class="text-emerald-400 font-medium">(+{@game_view.current_payout})</span>
              <% end %>
            </div>
          <% else %>
            <div class="text-xs text-gray-400">
              Sit & Go <span class="text-gray-500">·</span>
              {@game_context.players_remaining}/{@game_context.total_players} players
            </div>
          <% end %>
        </div>
      <% end %>

      <div style="transform: scale(var(--ui-scale, 0)); transform-origin: bottom left; width: calc(100vw / var(--ui-scale, 1));">
        <!-- Sit Out/In/Buy In Button - bottom-left corner -->
        <%= if @game_view.player_actions.is_participant do %>
          <div class="absolute left-5 bottom-5 z-10 flex">
            <!-- Buy In button (cash games) -->
            <%= if @game_view.player_actions.can_buy_in != false or @game_view.game_mode == :cash_game do %>
              <% can_buy_in = @game_view.player_actions.can_buy_in != false %>
              <div class="relative group">
                <button
                  phx-click={if can_buy_in, do: "show_buy_in"}
                  disabled={!can_buy_in}
                  class={[
                    "px-4 mr-4 py-2 rounded-lg font-medium text-sm transition-all shadow-md backdrop-blur-sm border",
                    if(can_buy_in,
                      do:
                        "bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white border-white/20 hover:shadow-lg cursor-pointer",
                      else: "bg-gray-600/50 text-gray-400 border-gray-500/20 cursor-not-allowed"
                    )
                  ]}
                >
                  <span class="flex items-center gap-1.5">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    Buy In
                  </span>
                </button>
                <%= unless can_buy_in do %>
                  <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-1.5 bg-gray-800 text-gray-300 text-xs rounded-lg whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none border border-gray-600">
                    Max chips reached
                  </div>
                <% end %>
              </div>
            <% end %>
            
    <!-- Sit Out / Sit In button -->
            <%= if @game_view.player_actions.can_sit_out do %>
              <button
                phx-click="sit_out"
                class="cursor-pointer px-4 py-2 rounded-lg font-medium text-sm transition-all shadow-md hover:shadow-lg backdrop-blur-sm border bg-amber-500/90 hover:bg-amber-600/95 text-white border-white/20"
              >
                <span class="flex items-center gap-1.5">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Sit Out
                </span>
              </button>
            <% end %>
            <%= if @game_view.player_actions.can_sit_in do %>
              <button
                phx-click="sit_in"
                class="cursor-pointer px-4 py-2 rounded-lg font-medium text-sm transition-all shadow-md hover:shadow-lg backdrop-blur-sm border bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white border-white/20"
              >
                <span class="flex items-center gap-1.5">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                    />
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Sit In
                </span>
              </button>
            <% end %>

            <%= if @game_view.my_hand_rank do %>
              <div>
                <div class="px-3 py-1.5 rounded-lg">
                  <span class="text-amber-400 text-[12px] font-semibold">
                    {@game_view.my_hand_rank.display_name}
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Action Controls - positioned and scaled -->
        <div class="absolute bottom-[16px] right-[16px]">
          <%= if Enum.any?(@game_view.valid_actions, fn {_key, value} -> value end) and is_nil(@current_animated_event_id) do %>
            <div class="bg-gray-900 rounded-xl p-4 shadow-2xl border-2 border-gray-700 flex flex-col">
              
    <!-- Raise Controls -->
              <%= if @game_view.valid_actions.raise do %>
                <div class="flex flex-row gap-3 mb-3">
                  <div class="flex gap-2 flex-wrap">
                    <%= for preset <- @game_view.valid_actions.raise.presets do %>
                      <button
                        type="button"
                        phx-click="update_raise_amount"
                        phx-value-raise_amount={preset.value}
                        class="cursor-pointer bg-gray-700 hover:bg-gray-600 text-gray-300 text-sm px-3 py-1.5 rounded"
                      >
                        {preset.label}
                      </button>
                    <% end %>
                  </div>
                  <div class="flex flex-col gap-0.5 flex-1">
                    <form phx-change="update_raise_amount">
                      <input
                        type="range"
                        name="raise_amount"
                        min={@game_view.valid_actions.raise.min}
                        max={@game_view.valid_actions.raise.max}
                        value={@raise_amount}
                        class="w-full h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-yellow-500"
                      />
                    </form>
                    <div class="flex justify-between text-sm text-gray-500 font-bold">
                      <span>{@game_view.valid_actions.raise.min}</span>
                      <span>{@game_view.valid_actions.raise.max}</span>
                    </div>
                  </div>
                </div>
              <% end %>

              <div class="flex gap-2 items-center">
                <!-- Fold Button -->
                <%= if @game_view.valid_actions.fold do %>
                  <.button
                    phx-click="fold_hand"
                    class="cursor-pointer bg-red-600 hover:bg-red-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    Fold
                  </.button>
                <% end %>
                <!-- Check Button -->
                <%= if @game_view.valid_actions.check do %>
                  <.button
                    phx-click="check_hand"
                    class="cursor-pointer bg-blue-600 hover:bg-blue-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    Check
                  </.button>
                <% end %>
                
    <!-- Call Button -->
                <%= if @game_view.valid_actions.call do %>
                  <.button
                    phx-click="call_hand"
                    class="cursor-pointer bg-green-600 hover:bg-green-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    Call {@game_view.valid_actions.call.amount}
                  </.button>
                <% end %>
                
    <!-- Raise Controls -->
                <%= if @game_view.valid_actions.raise do %>
                  <.button
                    phx-click="raise_hand"
                    phx-value-amount={@raise_amount}
                    class="cursor-pointer bg-yellow-600 hover:bg-yellow-700 text-white font-bold px-5 py-2.5 rounded-lg text-base"
                  >
                    <div class="w-[110px] text-center">
                      Raise {@raise_amount}
                    </div>
                  </.button>
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
          <div class="bg-gray-900 rounded-xl p-6 shadow-2xl border-2 border-gray-700 w-80">
            <h3 class="text-white text-lg font-bold mb-4">Buy In</h3>

            <div class="mb-4">
              <div class="text-center text-3xl font-bold text-amber-400 mb-3">
                ${@buy_in_amount}
              </div>
              <form phx-change="update_buy_in_amount">
                <input
                  type="range"
                  name="amount"
                  min={buy_in.min}
                  max={buy_in.max}
                  value={@buy_in_amount}
                  class="w-full h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-amber-500"
                />
              </form>
              <div class="flex justify-between text-sm text-gray-500 font-bold mt-1">
                <span>${buy_in.min}</span>
                <span>${buy_in.max}</span>
              </div>
            </div>

            <div class="flex gap-3">
              <button
                phx-click="close_buy_in"
                class="flex-1 px-4 py-2 rounded-lg font-medium text-sm bg-gray-700 hover:bg-gray-600 text-gray-300 transition-all"
              >
                Cancel
              </button>
              <button
                phx-click="confirm_buy_in"
                class="cursor-pointer flex-1 px-4 py-2 rounded-lg font-medium text-sm bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white transition-all"
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
