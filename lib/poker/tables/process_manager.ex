defmodule Poker.Tables.ProcessManager do
  @moduledoc """
  Process manager that orchestrates poker table workflows.

  Handles the automatic progression of hands:
  - Starts new hands after table starts or hand finishes
  - Advances rounds after all players act
  - Manages player timeouts via Oban jobs
  - Auto-folds sitting-out players when it's their turn
  - Pauses/resumes table based on player availability
  """

  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.Tables.ProcessManager",
    consistency: :strong

  alias Poker.Tables.Events.{
    TableCreated,
    TableStarted,
    RoundCompleted,
    TableFinished,
    HandFinished,
    ParticipantToActSelected,
    ParticipantFolded,
    ParticipantChecked,
    ParticipantCalled,
    ParticipantRaised,
    ParticipantWentAllIn,
    TablePaused,
    TableResumed,
    ParticipantSatIn,
    ParticipantBoughtIn,
    ParticipantJoined,
    ParticipantSatOut,
    ParticipantLeft,
    ParticipantBusted,
    RoundStarted
  }

  alias Poker.Tables.Commands.{
    StartHand,
    StartRound,
    FinishHand,
    ResumeTable,
    ParticipantFold,
    StartTable
  }

  alias Poker.Tournaments.Commands.RecordPlayerBust

  alias Poker.Tables.Jobs.{TimeoutJob, StartHandJob, AutoFoldJob}
  alias Poker.Tables.AtomDecoder

  require Logger

  @derive Jason.Encoder
  defstruct [
    :id,
    :timeout_seconds,
    :current_timeout_job_id,
    :table_status,
    :game_mode,
    :source_id,
    participants: []
  ]

  def interested?(%TableCreated{id: table_id} = _event, _metadata) do
    {:start, table_id}
  end

  def interested?(%TableStarted{id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantToActSelected{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%RoundCompleted{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%RoundStarted{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%HandFinished{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%TableFinished{table_id: table_id} = _event, _metadata) do
    {:stop, table_id}
  end

  # Player actions to cancel timeout
  def interested?(%ParticipantFolded{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantChecked{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantCalled{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantRaised{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantWentAllIn{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%TablePaused{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%TableResumed{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantSatIn{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantJoined{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantSatOut{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantBoughtIn{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantLeft{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(%ParticipantBusted{table_id: table_id} = _event, _metadata) do
    {:continue, table_id}
  end

  def interested?(_event, _metadata), do: false

  def handle(
        %Poker.Tables.ProcessManager{},
        %TableStarted{id: table_id} = _event
      ) do
    struct(StartHand, %{table_id: table_id, hand_id: UUIDv7.generate()})
  end

  def handle(
        %Poker.Tables.ProcessManager{game_mode: :tournament, participants: participants},
        %HandFinished{table_id: table_id} = _event
      ) do
    playing_count = Enum.count(participants, fn p -> not p.is_sitting_out end)

    if playing_count < 2 do
      # Delay scheduled in apply/2 via Oban
      []
    else
      struct(StartHand, %{table_id: table_id, hand_id: UUIDv7.generate()})
    end
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %HandFinished{table_id: table_id} = _event
      ) do
    struct(StartHand, %{table_id: table_id, hand_id: UUIDv7.generate()})
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %RoundCompleted{} = event
      ) do
    round_type = AtomDecoder.decode(:round_type, event.type)
    reason = AtomDecoder.decode(:round_reason, event.reason)

    cond do
      # If all players folded except one, finish the hand immediately
      reason == :all_folded ->
        struct(FinishHand, %{
          table_id: event.table_id,
          hand_id: event.hand_id,
          finish_reason: :all_folded
        })

      # If river round completed and all acted, go to showdown
      round_type == :river and reason == :all_acted ->
        struct(FinishHand, %{
          table_id: event.table_id,
          hand_id: event.hand_id,
          finish_reason: :showdown
        })

      # Otherwise, start next round
      reason == :all_acted ->
        struct(StartRound, %{
          round_id: UUIDv7.generate(),
          round: next_round(round_type),
          table_id: event.table_id,
          hand_id: event.hand_id
        })
    end
  end

  # Note: This check is now handled by the aggregate's StartHand handler
  # The aggregate uses filter_playing_participants to ensure only hands with
  # enough non-sitting-out players are started
  def handle(
        %Poker.Tables.ProcessManager{},
        %RoundStarted{} = _event
      ) do
    []
  end

  def handle(
        %Poker.Tables.ProcessManager{},
        %TableResumed{table_id: table_id} = _event
      ) do
    struct(StartHand, %{table_id: table_id, hand_id: UUIDv7.generate()})
  end

  def handle(
        %Poker.Tables.ProcessManager{table_status: :paused, participants: participants} = _state,
        %ParticipantSatIn{table_id: table_id} = _event
      ) do
    playing_participants = Enum.reject(participants, & &1.is_sitting_out)

    if length(playing_participants) === 1 do
      struct(ResumeTable, %{table_id: table_id})
    else
      []
    end
  end

  def handle(
        %Poker.Tables.ProcessManager{} = _state,
        %ParticipantSatIn{} = _event
      ) do
    []
  end

  def handle(
        %Poker.Tables.ProcessManager{} = _state,
        %ParticipantBoughtIn{} = _event
      ) do
    []
  end

  # Auto-fold for sitting-out players is scheduled via Oban in apply/2
  def handle(
        %Poker.Tables.ProcessManager{} = _state,
        %ParticipantToActSelected{} = _event
      ) do
    []
  end

  # Tournament tables are started by the Tournaments context, not the Tables PM
  def handle(
        %Poker.Tables.ProcessManager{table_status: :waiting, game_mode: :tournament},
        %ParticipantJoined{} = _event
      ) do
    []
  end

  # When a participant joins a waiting table, check if we should start
  # Note: handle runs BEFORE apply, so the joining participant isn't in the list yet
  def handle(
        %Poker.Tables.ProcessManager{table_status: :waiting, participants: participants} = _state,
        %ParticipantJoined{table_id: table_id, is_sitting_out: is_sitting_out} = _event
      ) do
    # Count existing non-sitting-out participants
    existing_playing_count = Enum.count(participants, fn p -> not p.is_sitting_out end)

    # Add 1 for the joining participant if they're not sitting out
    playing_count =
      if is_sitting_out, do: existing_playing_count, else: existing_playing_count + 1

    if playing_count >= 2 do
      struct(StartTable, %{table_id: table_id})
    else
      []
    end
  end

  # When a participant joins a paused table, check if we should resume
  # Note: handle runs BEFORE apply, so the joining participant isn't in the list yet
  def handle(
        %Poker.Tables.ProcessManager{table_status: :paused, participants: participants} = _state,
        %ParticipantJoined{table_id: table_id, is_sitting_out: is_sitting_out} = _event
      ) do
    # Count existing non-sitting-out participants
    existing_playing_count = Enum.count(participants, fn p -> not p.is_sitting_out end)

    # Add 1 for the joining participant if they're not sitting out
    playing_count =
      if is_sitting_out, do: existing_playing_count, else: existing_playing_count + 1

    if playing_count >= 2 do
      struct(ResumeTable, %{table_id: table_id})
    else
      []
    end
  end

  def handle(
        %Poker.Tables.ProcessManager{game_mode: :tournament, source_id: source_id},
        %ParticipantBusted{player_id: player_id}
      )
      when is_binary(source_id) do
    [%RecordPlayerBust{tournament_id: source_id, player_id: player_id}]
  end

  # Catch-all for events that only update state (no commands to dispatch)
  def handle(%Poker.Tables.ProcessManager{}, _event) do
    []
  end

  def apply(
        %__MODULE__{} = state,
        %TableCreated{
          id: id,
          timeout_seconds: timeout_seconds,
          status: status,
          game_mode: game_mode,
          source_id: source_id
        }
      ) do
    %__MODULE__{
      state
      | id: id,
        timeout_seconds: timeout_seconds,
        table_status: status,
        game_mode: game_mode,
        source_id: source_id,
        participants: []
    }
  end

  def apply(%__MODULE__{} = state, %TableStarted{} = _event) do
    %__MODULE__{state | table_status: :live}
  end

  @auto_fold_delay_seconds 2

  # When ParticipantToActSelected event is applied, schedule appropriate job
  def apply(
        %__MODULE__{timeout_seconds: timeout_seconds, participants: participants} = state,
        %ParticipantToActSelected{} = event
      ) do
    # Cancel any existing timeout job
    if state.current_timeout_job_id do
      Oban.cancel_job(state.current_timeout_job_id)
    end

    participant = Enum.find(participants, fn p -> p.id == event.participant_id end)

    {:ok, job} =
      if participant && participant.is_sitting_out do
        # Sitting out: auto-fold after short delay
        %{table_id: event.table_id, player_id: participant.player_id}
        |> AutoFoldJob.new(schedule_in: @auto_fold_delay_seconds, queue: :tables)
        |> Oban.insert()
      else
        # Active player: normal timeout
        %{
          table_id: event.table_id,
          participant_id: event.participant_id,
          round_id: event.round_id
        }
        |> TimeoutJob.new(schedule_in: timeout_seconds, queue: :tables)
        |> Oban.insert()
      end

    %__MODULE__{state | current_timeout_job_id: job.id}
  end

  def apply(%__MODULE__{} = state, %TablePaused{} = _event) do
    %__MODULE__{state | table_status: :paused}
  end

  def apply(%__MODULE__{} = state, %TableResumed{} = _event) do
    %__MODULE__{state | table_status: :live}
  end

  def apply(%__MODULE__{} = state, %TableFinished{} = _event) do
    if state.current_timeout_job_id do
      Oban.cancel_job(state.current_timeout_job_id)
    end

    %__MODULE__{state | table_status: :finished}
  end

  def apply(%__MODULE__{participants: participants} = state, %ParticipantJoined{} = event) do
    new_participant = %{
      id: event.id,
      player_id: event.player_id,
      is_sitting_out: event.is_sitting_out
    }

    %__MODULE__{state | participants: participants ++ [new_participant]}
  end

  def apply(%__MODULE__{participants: participants} = state, %ParticipantSatOut{} = event) do
    updated_participants =
      Enum.map(participants, fn p ->
        if p.id == event.participant_id do
          %{p | is_sitting_out: true}
        else
          p
        end
      end)

    %__MODULE__{state | participants: updated_participants}
  end

  def apply(%__MODULE__{} = state, %ParticipantBoughtIn{} = _event) do
    # Pending buy-in only — no state change until hand start
    state
  end

  def apply(%__MODULE__{participants: participants} = state, %ParticipantSatIn{} = event) do
    updated_participants =
      Enum.map(participants, fn p ->
        if p.id == event.participant_id do
          %{p | is_sitting_out: false}
        else
          p
        end
      end)

    %__MODULE__{state | participants: updated_participants}
  end

  def apply(%__MODULE__{participants: participants} = state, %ParticipantLeft{} = event) do
    updated_participants = Enum.reject(participants, &(&1.id == event.participant_id))
    %__MODULE__{state | participants: updated_participants}
  end

  @hand_delay_seconds 3

  def apply(
        %__MODULE__{game_mode: :tournament, participants: participants} = state,
        %HandFinished{table_id: table_id}
      ) do
    playing_count = Enum.count(participants, fn p -> not p.is_sitting_out end)

    if playing_count < 2 do
      %{table_id: table_id}
      |> StartHandJob.new(schedule_in: @hand_delay_seconds, queue: :tables)
      |> Oban.insert()
    end

    state
  end

  def apply(%__MODULE__{} = state, _event) do
    state
  end

  # Skip events that fail due to corrupted state rather than stopping the PM
  def error({:error, error}, _event_or_command, _failure_context) do
    Logger.error("#{__MODULE__} error: #{inspect(error)}")
    :skip
  end

  def next_round(round) do
    case round do
      :pre_flop -> :flop
      :flop -> :turn
      :turn -> :river
    end
  end
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.ProcessManager do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.ProcessManager{} = pm) do
    %Poker.Tables.ProcessManager{
      pm
      | table_status: decode_atom(:table_status, pm.table_status),
        game_mode: decode_atom(:game_mode, pm.game_mode),
        participants: pm.participants || []
    }
  end

  defp decode_atom(_field, nil), do: nil
  defp decode_atom(_field, value) when is_atom(value), do: value
  defp decode_atom(field, value) when is_binary(value), do: AtomDecoder.decode(field, value)
end
