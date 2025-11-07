defmodule Poker.Tables do
  alias Poker.Tables.Commands.{CreateTable, JoinTableParticipant}
  alias Poker.Tables.Projections.{Table, Participant}

  def create_table(creator, settings_attrs \\ %{}) do
    table_id = Ecto.UUID.generate()
    settings_id = Ecto.UUID.generate()
    creator_participant_id = Ecto.UUID.generate()

    settings_attrs =
      settings_attrs
      |> Map.put(:settings_id, settings_id)
      |> Map.put(:table_id, table_id)

    command_attrs = %{
      table_id: table_id,
      creator_id: creator.id,
      creator_participant_id: creator_participant_id,
      settings: settings_attrs
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Table, table_id)
    end
  end

  def join_participant(table, player) do
    participant_id = Ecto.UUID.generate()
    table = Poker.Repo.preload(table, :settings)

    command_attrs = %{
      participant_id: participant_id,
      player_id: player.id,
      table_id: table.id,
      chips: table.settings.starting_stack
    }

    with {:ok, command} <-
           Poker.Repo.validate_changeset(command_attrs, &JoinTableParticipant.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Participant, participant_id)
    end
  end
end
