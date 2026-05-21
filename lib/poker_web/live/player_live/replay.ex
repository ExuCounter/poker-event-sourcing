defmodule PokerWeb.PlayerLive.Replay do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables
  alias PokerWeb.JsonEncoder
  alias Poker.Tables.Views.HandReplay

  @impl true
  def mount(%{"id" => table_id} = params, _session, socket) do
    lobby = Tables.get_lobby(socket.assigns.current_scope, table_id)

    if is_nil(lobby) do
      {:ok,
       socket
       |> put_flash(:error, "Table not found")
       |> push_navigate(to: ~p"/")}
    else
      hand_id = Map.get(params, "hand_id", :previous)
      player_id = socket.assigns.current_scope.user.id

      replay = HandReplay.initialize(table_id, player_id, hand_id)

      table = Poker.Repo.get(Poker.Tables.Projections.TableLobby, table_id)

      lobby_path =
        case table do
          %{game_mode: :tournament, source_id: tid} when is_binary(tid) ->
            ~p"/tournaments/#{tid}/lobby"

          _ ->
            ~p"/cash/#{table_id}/lobby"
        end

      if replay.total_steps == 0 do
        {:ok,
         socket
         |> put_flash(:info, "No hand to replay yet")
         |> push_navigate(to: lobby_path)}
      else
        {:ok,
         assign(socket,
           table_id: table_id,
           lobby_path: lobby_path,
           replay: replay,
           current_user_id: player_id,
           playing: false
         )}
      end
    end
  end

  # Step controls

  @impl true
  def handle_event("step_forward", _params, socket) do
    case HandReplay.step_forward(socket.assigns.replay) do
      {:ok, updated_replay} ->
        socket = assign(socket, replay: updated_replay)
        socket = push_event_to_frontend(socket, updated_replay.next_event)
        {:noreply, socket}

      {:error, :at_end} ->
        {:noreply, put_flash(socket, :info, "End of replay")}
    end
  end

  def handle_event("step_backward", _params, socket) do
    case HandReplay.step_backward(socket.assigns.replay) do
      {:ok, updated_replay} ->
        socket = assign(socket, replay: updated_replay)
        # Rebuild entire canvas state for backward step
        socket = push_full_state(socket, updated_replay.current_state)
        {:noreply, socket}

      {:error, :at_start} ->
        {:noreply, put_flash(socket, :info, "At start of replay")}
    end
  end

  def handle_event("toggle_play", _params, socket) do
    updated_replay = HandReplay.toggle_play(socket.assigns.replay)

    socket =
      if updated_replay.playing do
        # Start auto-play timer (1 second interval)
        Process.send_after(self(), :auto_step, 1000)
        assign(socket, playing: true)
      else
        # Stop auto-play
        assign(socket, playing: false)
      end

    {:noreply, assign(socket, replay: updated_replay)}
  end

  def handle_event("reset", _params, socket) do
    updated_replay = HandReplay.reset(socket.assigns.replay)
    socket = assign(socket, replay: updated_replay, playing: false)
    socket = push_full_state(socket, updated_replay.current_state)
    {:noreply, socket}
  end

  # Auto-play handler

  @impl true
  def handle_info(:auto_step, socket) do
    if socket.assigns.replay.playing do
      case HandReplay.step_forward(socket.assigns.replay) do
        {:ok, updated_replay} ->
          socket = assign(socket, replay: updated_replay)
          socket = push_event_to_frontend(socket, updated_replay.next_event)

          Process.send_after(self(), :auto_step, 1000)

          {:noreply, socket}

        {:error, :at_end} ->
          # Stop playing at end
          updated_replay = %{socket.assigns.replay | playing: false}
          {:noreply, assign(socket, replay: updated_replay)}
      end
    else
      {:noreply, socket}
    end
  end

  # Private helpers

  defp push_event_to_frontend(socket, event) when is_nil(event) do
    socket
  end

  defp push_event_to_frontend(socket, event) do
    push_event(socket, "table_event", %{
      event: JsonEncoder.transform_keys(event),
      new_state: JsonEncoder.transform_keys(socket.assigns.replay.current_state)
    })
  end

  defp push_full_state(socket, state) do
    push_event(socket, "rebuild_state", %{
      state: JsonEncoder.transform_keys(state)
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash kind={:error} flash={@flash} />
    <.flash kind={:info} flash={@flash} />
    <div style="height: 100vh; position: relative; overflow: hidden;">
      <!-- Replay controls - bottom right -->
      <div style="transform: scale(var(--ui-scale, 1)); transform-origin: bottom left; width: calc(100vw / var(--ui-scale, 1)); position: absolute; bottom: 0; left: 0;">
        <div class="absolute bottom-4 right-4">
          <div class="flex items-center gap-2 px-3 py-2 rounded-xl border border-[var(--pkr-line)] bg-black/80 backdrop-blur-lg font-[family-name:var(--pkr-font-ui)]">
            <button
              phx-click="step_backward"
              disabled={@replay.current_step == 0}
              class={"w-9 h-9 rounded-full flex items-center justify-center text-[13px] border border-[var(--pkr-line)] transition-all cursor-pointer " <>
                if(@replay.current_step == 0, do: "opacity-30 cursor-not-allowed text-[var(--pkr-ink-3)] bg-[var(--pkr-bg-2)]", else: "text-[var(--pkr-ink-1)] bg-[var(--pkr-bg-2)] hover:bg-[var(--pkr-bg-1)]")}
            >
              &#x23EE;
            </button>

            <button
              phx-click="toggle_play"
              class="w-9 h-9 rounded-full flex items-center justify-center text-[13px] bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
            >
              {if @replay.playing, do: "⏸", else: "▶"}
            </button>

            <button
              phx-click="step_forward"
              disabled={@replay.current_step >= @replay.total_steps}
              class={"w-9 h-9 rounded-full flex items-center justify-center text-[13px] border border-[var(--pkr-line)] transition-all cursor-pointer " <>
                if(@replay.current_step >= @replay.total_steps, do: "opacity-30 cursor-not-allowed text-[var(--pkr-ink-3)] bg-[var(--pkr-bg-2)]", else: "text-[var(--pkr-ink-1)] bg-[var(--pkr-bg-2)] hover:bg-[var(--pkr-bg-1)]")}
            >
              &#x23ED;
            </button>

            <button
              phx-click="reset"
              class="w-9 h-9 rounded-full flex items-center justify-center text-[13px] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] bg-[var(--pkr-bg-2)] hover:bg-[var(--pkr-bg-1)] transition-all cursor-pointer"
            >
              &#x21BA;
            </button>

            <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)] ml-1">
              {@replay.current_step}/{@replay.total_steps}
            </span>
          </div>
        </div>
      </div>
      
    <!-- Canvas -->
      <canvas
        id="poker-canvas"
        phx-hook="PokerCanvas"
        phx-update="ignore"
        data-state={JsonEncoder.transform_keys(@replay.current_state) |> Jason.encode!()}
        data-current-user-id={@current_user_id}
        data-mode="replay"
      />
    </div>
    """
  end
end
