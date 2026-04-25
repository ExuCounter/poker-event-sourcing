defmodule PokerWeb.PlayerLive.Replay do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables
  alias PokerWeb.JsonEncoder
  alias Poker.Tables.Views.HandReplay

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    lobby = Tables.get_lobby(table_id)

    if is_nil(lobby) do
      {:ok,
       socket
       |> put_flash(:error, "Table not found")
       |> push_navigate(to: ~p"/")}
    else
      # Initialize replay session for previous hand
      replay =
        HandReplay.initialize(
          table_id,
          socket.assigns.current_scope.user.id,
          :previous
        )

      # Check if replay has events
      socket =
        if replay.total_steps == 0 do
          put_flash(socket, :info, "No previous hand to replay")
        else
          socket
        end

      table = Poker.Repo.get(Poker.Tables.Projections.TableList, table_id)

      lobby_path =
        case table do
          %{game_mode: :tournament, source_id: tid} when is_binary(tid) -> ~p"/tournaments/#{tid}/lobby"
          _ -> ~p"/cash/#{table_id}/lobby"
        end

      {:ok,
       assign(socket,
         table_id: table_id,
         lobby_path: lobby_path,
         replay: replay,
         current_user_id: socket.assigns.current_scope.user.id,
         playing: false
       )}
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
    # Event is already transformed by EventTransformer (has event_id, type, and timing)
    # Just need to transform keys for JSON encoding
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
      <div style="transform: scale(var(--game-scale, 1)); transform-origin: bottom left; width: calc(100vw / var(--game-scale, 1)); position: absolute; bottom: 0; left: 0;">
        <div
          class="absolute bottom-[16px] right-[16px]"
          style="transform: scale(var(--button-boost, 1)); transform-origin: bottom right;"
        >
          <div
            class="replay-controls"
            style="background: rgba(0, 0, 0, 0.8); padding: 10px 16px; border-radius: 8px; display: flex; align-items: center; gap: 8px;"
          >
            <button
              phx-click="step_backward"
              disabled={@replay.current_step == 0}
              style="padding: 8px 10px; background: #4CAF50; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px;"
              class={if @replay.current_step == 0, do: "opacity-50 cursor-not-allowed", else: ""}
            >
              ←
            </button>

            <button
              phx-click="toggle_play"
              style="padding: 8px 12px; background: #2196F3; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; font-weight: bold;"
            >
              {if @replay.playing, do: "⏸", else: "▶"}
            </button>

            <button
              phx-click="step_forward"
              disabled={@replay.current_step >= @replay.total_steps}
              style="padding: 8px 10px; background: #4CAF50; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px;"
              class={
                if @replay.current_step >= @replay.total_steps,
                  do: "opacity-50 cursor-not-allowed",
                  else: ""
              }
            >
              →
            </button>

            <button
              phx-click="reset"
              style="padding: 8px 10px; background: #FF9800; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px;"
            >
              ↺
            </button>

            <span style="color: white; font-size: 12px; margin-left: 4px; font-family: monospace;">
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
