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
      # Stream ALL table events from the beginning (not just hand events)
      all_table_events =
        "table-#{replay.table_id}"
        |> Poker.EventStore.stream_forward()
        |> Enum.to_list()

      # Find the step event in the full table event stream by event_id
      step_event_idx =
        Enum.find_index(all_table_events, fn event ->
          event.event_id == step_event_info.event_id
        end)

      if is_nil(step_event_idx) do
        # Event not found, return current state
        replay.current_state
      else
        # Apply ALL events from beginning up to and including this step
        events_to_apply = Enum.take(all_table_events, step_event_idx + 1)

        # Build aggregate from empty Table (not from current_state!)
        aggregate =
          events_to_apply
          |> Enum.map(fn %{data: data} -> data end)
          |> Enum.reduce(%Table{}, &Table.apply(&2, &1))

        # Convert to player view with replay visibility
        GameStateBuilder.build_view(aggregate, replay.player_id, [], step_event_info.event_id,
          visibility_mode: :replay,
          calculate_actions: false
        )
      end
    end
  end

  defp build_initial_state(table_id, player_id, hand_events) do
    # Build state at HandStarted event to have proper table context
    # We need ALL table events from the beginning, not just hand events

    # Get the hand_id from the first event
    hand_id = extract_hand_id(hand_events)

    if is_nil(hand_id) do
      # No hand found, return empty state
      GameStateBuilder.build_view(%Table{}, player_id, [], nil,
        visibility_mode: :replay,
        calculate_actions: false
      )
    else
      # Stream ALL table events from the beginning
      all_table_events =
        "table-#{table_id}"
        |> Poker.EventStore.stream_forward()
        |> Enum.to_list()

      # Find HandStarted event with this hand_id in full event stream
      hand_started_idx =
        Enum.find_index(all_table_events, fn event ->
          case event do
            %{data: %Poker.Tables.Events.HandStarted{id: ^hand_id}} -> true
            _ -> false
          end
        end)

      # Build aggregate from ALL events up to and including HandStarted
      events_to_apply = Enum.take(all_table_events, hand_started_idx + 1)

      aggregate =
        events_to_apply
        |> Enum.map(fn %{data: data} -> data end)
        |> Enum.reduce(%Table{}, &Table.apply(&2, &1))

      event_id =
        case Enum.at(all_table_events, hand_started_idx) do
          %{event_id: id} -> id
          _ -> nil
        end

      GameStateBuilder.build_view(aggregate, player_id, [], event_id,
        visibility_mode: :replay,
        calculate_actions: false
      )
    end
  end

  defp extract_hand_id([]), do: nil

  defp extract_hand_id([%{data: %{id: id}} | _]) when is_binary(id), do: id

  defp extract_hand_id(_), do: nil
end
