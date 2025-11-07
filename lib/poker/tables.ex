defmodule Poker.Tables do
  alias Poker.Tables.Commands.{CreateTable, JoinTableParticipant}
  alias Poker.Tables.Projections.{Table, TableParticipant}

  def create_table(creator, settings_attrs \\ %{}) do
    table_uuid = Ecto.UUID.generate()
    settings_uuid = Ecto.UUID.generate()

    settings_attrs =
      settings_attrs
      |> Map.put(:settings_uuid, settings_uuid)
      |> Map.put(:table_uuid, table_uuid)

    command_attrs = %{
      table_uuid: table_uuid,
      creator_uuid: creator.id,
      settings: settings_attrs
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Table, table_uuid)
    end
  end

  def join_participant(table, player) do
    participant_uuid = Ecto.UUID.generate()
    table = Poker.Repo.preload(table, :settings)

    command_attrs = %{
      participant_uuid: participant_uuid,
      player_uuid: player.id,
      table_uuid: table.id,
      chips: table.settings.starting_stack
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &JoinTableParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(TableParticipant, participant_uuid)
    end
  end
end
