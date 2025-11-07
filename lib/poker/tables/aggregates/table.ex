defmodule Poker.Tables.Aggregates.Table do
  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Commands.{CreateTable, JoinTableParticipant}
  alias Poker.Tables.Events.{TableCreated, TableSettingsCreated, TableParticipantJoined}

  defstruct [
    :id,
    :creator_id,
    :status,
    :settings,
    participants: []
  ]

  def execute(
        %Table{} = _table,
        %CreateTable{table_uuid: table_uuid, creator_uuid: creator_uuid, settings: settings} =
          _event
      ) do
    [
      %TableCreated{
        id: table_uuid,
        creator_id: creator_uuid,
        status: :not_started
      },
      %TableSettingsCreated{
        table_id: table_uuid,
        id: settings.settings_uuid,
        big_blind: settings.big_blind,
        small_blind: settings.small_blind,
        starting_stack: settings.starting_stack,
        timeout_seconds: settings.timeout_seconds
      },
      %TableParticipantJoined{
        id: Ecto.UUID.generate(),
        player_id: creator_uuid,
        table_id: table_uuid,
        chips: settings.starting_stack,
        seat_number: 1,
        status: :active
      }
    ]
  end

  def execute(%Table{participants: participants} = _table, %JoinTableParticipant{} = join) do
    seat_number = length(participants) + 1

    %TableParticipantJoined{
      id: join.participant_uuid,
      player_id: join.player_uuid,
      table_id: join.table_uuid,
      chips: join.chips,
      seat_number: seat_number,
      status: :active
    }
  end

  # State mutators

  def apply(%Table{} = table, %TableSettingsCreated{} = created) do
    settings = %{
      id: created.id,
      table_id: created.table_id,
      small_blind: created.small_blind,
      big_blind: created.big_blind,
      starting_stack: created.starting_stack,
      timeout_seconds: created.timeout_seconds
    }

    %Table{table | settings: settings}
  end

  def apply(%Table{} = _table, %TableCreated{} = created) do
    %Table{
      id: created.id,
      creator_id: created.creator_id,
      status: created.status,
      participants: []
    }
  end

  def apply(%Table{participants: participants} = table, %TableParticipantJoined{} = joined) do
    new_participant = %{
      id: joined.id,
      player_id: joined.player_id,
      chips: joined.chips,
      seat_number: joined.seat_number,
      status: joined.status
    }

    %Table{table | participants: participants ++ [new_participant]}
  end
end
