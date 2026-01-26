defmodule Poker.Tables.Views.HandReplay do
  @moduledoc """
  Manages hand replay sessions with step controls.

  Provides play/pause/reset/step forward/backward functionality for
  reviewing completed poker hands.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Views.{GameStateBuilder, ReplayEvents}
  alias Poker.Tables.Queries.HandEvents

  @doc """
  Initializes a hand replay session.

  ## Parameters
    * `table_id` - The table identifier
    * `player_id` - The player for whom to build views
    * `hand_id` - `:previous` or a specific hand UUID

  ## Returns

  A replay session map with:
    * `:table_id` - Table identifier
    * `:player_id` - Player identifier
    * `:hand_id` - Hand being replayed (nil if no hand found)
    * `:events` - List of animated events with positions
    * `:all_events` - Full event list for state building
    * `:total_steps` - Total number of animated events
    * `:current_step` - Current step index (0 = start)
    * `:current_state` - Current player view state
    * `:playing` - Whether auto-play is active
    * `:next_event` - Next event to animate (nil at start)
  """
  def initialize(table_id, player_id, hand_id \\ :previous) do
    # Get hand events
    {events, actual_hand_id} =
      case hand_id do
        :previous ->
          case HandEvents.get_previous_hand_events(table_id) do
            {:ok, events} -> {events, extract_hand_id(events)}
            {:error, _} -> {[], nil}
          end

        id when is_binary(id) ->
          events = HandEvents.get_hand_events(table_id, id)
          {events, id}
      end

    # Filter to animated events only
    steppable_events = ReplayEvents.build_step_events(events)

    # Build initial state (table at HandStarted event with context)
    initial_state = build_initial_state(table_id, player_id, events)

    %{
      table_id: table_id,
      player_id: player_id,
      hand_id: actual_hand_id,
      events: steppable_events,
      all_events: events,
      total_steps: length(steppable_events),
      current_step: 0,
      current_state: initial_state,
      playing: false,
      next_event: nil
    }
  end

  @doc """
  Steps forward to next event.

  ## Returns
    * `{:ok, updated_replay}` with next event ready to animate
    * `{:error, :at_end}` if already at the end
  """
  def step_forward(replay) do
    if replay.current_step >= replay.total_steps do
      {:error, :at_end}
    else
      next_step = replay.current_step + 1
      next_event_info = Enum.at(replay.events, next_step - 1)

      # Build state up to this event
      new_state = build_state_at_step(replay, next_step)

      # Transform the event using EventTransformer for consistent formatting
      # The event already has event_id from EventStore metadata
      transformed_event = Poker.Tables.EventTransformer.transform(next_event_info.event)

      {:ok,
       %{
         replay
         | current_step: next_step,
           current_state: new_state,
           next_event: transformed_event
       }}
    end
  end

  @doc """
  Steps backward to previous event.

  ## Returns
    * `{:ok, updated_replay}` with state at previous step
    * `{:error, :at_start}` if already at the beginning
  """
  def step_backward(replay) do
    if replay.current_step == 0 do
      {:error, :at_start}
    else
      prev_step = replay.current_step - 1

      # Rebuild state up to previous step
      new_state = build_state_at_step(replay, prev_step)

      {:ok, %{replay | current_step: prev_step, current_state: new_state, next_event: nil}}
    end
  end

  @doc """
  Resets replay to beginning.
  """
  def reset(replay) do
    %{
      replay
      | current_step: 0,
        current_state: build_initial_state(replay.table_id, replay.player_id, replay.all_events),
        playing: false,
        next_event: nil
    }
  end

  @doc """
  Toggles play/pause state.
  """
  def toggle_play(replay) do
    %{replay | playing: !replay.playing}
  end

  # Private helpers

  defp build_state_at_step(replay, step) when step == 0 do
    build_initial_state(replay.table_id, replay.player_id, replay.all_events)
  end

  defp build_state_at_step(replay, step) do
    step_event_info = Enum.at(replay.events, step - 1)

    if is_nil(step_event_info) do
      replay.current_state
    else
      {hand_history, hand_events} = HandEvents.get_hand_events(replay.table_id, replay.hand_id)

      aggregate = :erlang.binary_to_term(hand_history.initial_state)

      step_event_idx =
        Enum.find_index(hand_events, fn event ->
          event.event_id == step_event_info.event_id
        end)

      events_to_apply = Enum.take(hand_events, step_event_idx + 1)

      aggregate =
        events_to_apply
        |> Enum.map(fn %{data: data} -> data end)
        |> Enum.reduce(aggregate, &Table.apply(&2, &1))

      GameStateBuilder.build_view(
        aggregate,
        replay.player_id,
        [],
        step_event_info.event_id,
        visibility_mode: :replay,
        calculate_actions: false
      )
    end
  end

  defp build_initial_state(table_id, player_id, hand_events) do
    hand_id = extract_hand_id(hand_events)
    hand_history = get_hand_history(hand_id)
    aggregate = :erlang.binary_to_term(hand_history.initial_state)
    stream_id = "table-#{table_id}"

    {:ok, [hand_started_event]} =
      Poker.EventStore.read_stream_forward(
        stream_id,
        hand_history.start_version,
        1
      )

    aggregate = Table.apply(aggregate, hand_started_event.data)

    GameStateBuilder.build_view(
      aggregate,
      player_id,
      [],
      hand_started_event.event_id,
      visibility_mode: :replay,
      calculate_actions: false
    )
  end

  defp extract_hand_id([]), do: nil

  defp extract_hand_id([%{data: %{id: id}} | _]) when is_binary(id), do: id

  defp extract_hand_id(_), do: nil

  defp get_hand_history(hand_id) do
    import Ecto.Query

    from(h in Poker.Tables.Projections.HandHistory,
      where: h.hand_id == ^hand_id
    )
    |> Poker.Repo.one!()
  end
end
