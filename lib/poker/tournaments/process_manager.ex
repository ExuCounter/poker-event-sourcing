defmodule Poker.Tournaments.ProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.Tournaments.ProcessManager",
    consistency: :strong

  alias Poker.Tournaments.Events.{
    TournamentCreated,
    PlayerRegistered,
    TournamentStarted,
    BlindLevelAdvanced,
    TournamentPlayerBusted,
    TournamentTableCreated,
    TournamentFinished
  }

  alias Poker.Tables.Events.TableCreated

  alias Poker.Tables.Commands.{
    CreateTable,
    CreateTableSettings,
    JoinTableParticipant,
    StartTable,
    UpdateTableBlinds
  }

  alias Poker.Tournaments.Commands.{FinishTournament, RecordTournamentTable}
  alias Poker.Tournaments.Jobs.BlindAdvanceJob
  alias Poker.Tournaments.BlindStructure

  require Logger

  @derive Jason.Encoder
  defstruct [
    :id,
    :creator_id,
    :speed,
    :starting_stack,
    :table_type,
    :current_level,
    :current_blind_job_id,
    table_ids: [],
    registered_players: [],
    players_remaining: 0,
    total_players: 0
  ]

  def interested?(%TournamentCreated{id: id}, _metadata), do: {:start, id}
  def interested?(%PlayerRegistered{tournament_id: id}, _metadata), do: {:continue, id}
  def interested?(%TournamentStarted{tournament_id: id}, _metadata), do: {:continue, id}
  def interested?(%BlindLevelAdvanced{tournament_id: id}, _metadata), do: {:continue, id}
  def interested?(%TournamentPlayerBusted{tournament_id: id}, _metadata), do: {:continue, id}
  def interested?(%TournamentTableCreated{tournament_id: id}, _metadata), do: {:continue, id}
  def interested?(%TournamentFinished{tournament_id: id}, _metadata), do: {:stop, id}

  def interested?(%TableCreated{source_id: source_id}, _metadata) when is_binary(source_id) do
    {:continue, source_id}
  end

  def interested?(_event, _metadata), do: false

  # COMMAND DISPATCH

  def handle(%__MODULE__{}, %TournamentCreated{}), do: []
  def handle(%__MODULE__{}, %PlayerRegistered{}), do: []

  def handle(%__MODULE__{id: tournament_id}, %TableCreated{id: table_id}) do
    [%RecordTournamentTable{tournament_id: tournament_id, table_id: table_id}]
  end

  def handle(%__MODULE__{} = state, %TournamentStarted{tournament_id: tournament_id}) do
    table_id = UUIDv7.generate()
    blind = BlindStructure.get_level(1)

    create_table = %CreateTable{
      table_id: table_id,
      creator_id: state.creator_id,
      settings_id: UUIDv7.generate(),
      game_mode: :tournament,
      source_id: tournament_id,
      settings: %CreateTableSettings{
        small_blind: blind.small_blind,
        big_blind: blind.big_blind,
        starting_stack: state.starting_stack,
        timeout_seconds: 30,
        table_type: state.table_type
      }
    }

    join_commands =
      state.registered_players
      |> Enum.with_index(1)
      |> Enum.map(fn {player_id, seat_number} ->
        %JoinTableParticipant{
          table_id: table_id,
          player_id: player_id,
          participant_id: UUIDv7.generate(),
          starting_stack: state.starting_stack,
          seat_number: seat_number
        }
      end)

    start_table = %StartTable{table_id: table_id}

    [create_table | join_commands] ++ [start_table]
  end

  def handle(%__MODULE__{table_ids: table_ids}, %BlindLevelAdvanced{} = event) do
    Enum.map(table_ids, fn table_id ->
      %UpdateTableBlinds{
        table_id: table_id,
        small_blind: event.small_blind,
        big_blind: event.big_blind
      }
    end)
  end

  def handle(%__MODULE__{players_remaining: remaining}, %TournamentPlayerBusted{
        tournament_id: tournament_id
      }) do
    if remaining - 1 == 1 do
      [%FinishTournament{tournament_id: tournament_id}]
    else
      []
    end
  end

  def handle(%__MODULE__{}, %TournamentTableCreated{}), do: []
  def handle(%__MODULE__{}, %TournamentFinished{}), do: []

  # STATE UPDATES

  def apply(%__MODULE__{} = state, %TournamentCreated{} = event) do
    %__MODULE__{
      state
      | id: event.id,
        creator_id: event.creator_id,
        speed: event.speed,
        starting_stack: event.starting_stack,
        table_type: event.table_type,
        total_players: event.max_players
    }
  end

  def apply(%__MODULE__{} = state, %PlayerRegistered{player_id: player_id}) do
    %__MODULE__{state | registered_players: state.registered_players ++ [player_id]}
  end

  def apply(%__MODULE__{} = state, %TournamentStarted{}) do
    duration = BlindStructure.duration_seconds(state.speed)

    {:ok, job} =
      %{tournament_id: state.id, level: 2}
      |> BlindAdvanceJob.new(schedule_in: duration, queue: :tournaments)
      |> Oban.insert()

    %__MODULE__{
      state
      | current_level: 1,
        current_blind_job_id: job.id,
        players_remaining: state.total_players
    }
  end

  def apply(%__MODULE__{} = state, %TableCreated{id: table_id}) do
    %__MODULE__{state | table_ids: state.table_ids ++ [table_id]}
  end

  def apply(%__MODULE__{} = state, %BlindLevelAdvanced{level: level}) do
    if state.current_blind_job_id do
      Oban.cancel_job(state.current_blind_job_id)
    end

    job_id =
      if level < BlindStructure.max_level() do
        duration = BlindStructure.duration_seconds(state.speed)

        {:ok, job} =
          %{tournament_id: state.id, level: level + 1}
          |> BlindAdvanceJob.new(schedule_in: duration, queue: :tournaments)
          |> Oban.insert()

        job.id
      else
        nil
      end

    %__MODULE__{state | current_level: level, current_blind_job_id: job_id}
  end

  def apply(%__MODULE__{} = state, %TournamentPlayerBusted{}) do
    %__MODULE__{state | players_remaining: state.players_remaining - 1}
  end

  def apply(%__MODULE__{} = state, %TournamentFinished{}) do
    if state.current_blind_job_id do
      Oban.cancel_job(state.current_blind_job_id)
    end

    state
  end

  def error({:error, error}, _event_or_command, _failure_context) do
    Logger.error("#{__MODULE__} error: #{inspect(error)}")
    :skip
  end
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tournaments.ProcessManager do
  alias Poker.Tournaments.AtomDecoder

  def decode(%Poker.Tournaments.ProcessManager{} = pm) do
    %Poker.Tournaments.ProcessManager{
      pm
      | speed: decode_atom(:speed, pm.speed),
        table_type: decode_atom(:table_type, pm.table_type)
    }
  end

  defp decode_atom(_field, nil), do: nil
  defp decode_atom(_field, value) when is_atom(value), do: value
  defp decode_atom(field, value) when is_binary(value), do: AtomDecoder.decode(field, value)
end
