defmodule Poker.Tables.ProcessManager do
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
    ParticipantJoined,
    ParticipantSatOut,
    RoundStarted
  }

  alias Poker.Tables.Commands.{StartHand, StartRound, FinishHand, ResumeTable, ParticipantFold}
  alias Poker.Tables.Jobs.TimeoutJob

  @derive Jason.Encoder
  defstruct [:id, :timeout_seconds, :current_timeout_job_id, :table_status, :participants]

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

  def interested?(_event, _metadata), do: false

  def handle(
        %Poker.Tables.ProcessManager{},
        %TableStarted{id: table_id} = _event
      ) do
    struct(StartHand, %{table_id: table_id, hand_id: UUIDv7.generate()})
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
    round_type = event.type |> String.to_existing_atom()
    reason = event.reason |> String.to_existing_atom()

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
        %Poker.Tables.ProcessManager{participants: participants} = _state,
        %ParticipantToActSelected{} = event
      ) do
    participant = Enum.find(participants, fn p -> p.id == event.participant_id end)

    if participant && participant.is_sitting_out do
      struct(ParticipantFold, %{
        hand_action_id: UUIDv7.generate(),
        player_id: participant.player_id,
        table_id: event.table_id
      })
    else
      []
    end
  end

  def apply(
        %__MODULE__{} = state,
        %TableCreated{id: id, timeout_seconds: timeout_seconds, status: status} = _event
      ) do
    %__MODULE__{
      state
      | id: id,
        timeout_seconds: timeout_seconds,
        table_status: status,
        participants: []
    }
  end

  def apply(%__MODULE__{} = state, %TableStarted{} = _event) do
    %__MODULE__{state | table_status: :live}
  end

  # When ParticipantToActSelected event is applied, schedule Oban job
  def apply(
        %__MODULE__{timeout_seconds: timeout_seconds} = state,
        %ParticipantToActSelected{} = event
      ) do
    # Cancel any existing timeout job
    if state.current_timeout_job_id do
      Oban.cancel_job(state.current_timeout_job_id)
    end

    # Schedule timeout job in tables queue
    {:ok, job} =
      %{
        table_id: event.table_id,
        participant_id: event.participant_id,
        round_id: event.round_id
      }
      |> TimeoutJob.new(schedule_in: timeout_seconds, queue: :tables)
      |> Oban.insert()

    %__MODULE__{state | current_timeout_job_id: job.id}
  end

  # When participant acts (fold/check/call/raise/all_in), cancel timeout
  def apply(%__MODULE__{current_timeout_job_id: job_id} = state, event)
      when event.__struct__ in [ParticipantToActSelected] do
    # Cancel the scheduled timeout job
    if job_id do
      Oban.cancel_job(job_id)
    end

    %__MODULE__{state | current_timeout_job_id: nil}
  end

  def apply(%__MODULE__{} = state, %TablePaused{} = _event) do
    %__MODULE__{state | table_status: :paused}
  end

  def apply(%__MODULE__{} = state, %TableResumed{} = _event) do
    %__MODULE__{state | table_status: :live}
  end

  def apply(%__MODULE__{} = state, %TableFinished{} = _event) do
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

  def apply(%__MODULE__{} = state, _event) do
    state
  end

  def next_round(round) do
    case round do
      :pre_flop -> :flop
      :flop -> :turn
      :turn -> :river
    end
  end
end
