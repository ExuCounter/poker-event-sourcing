defmodule Poker.Tables do
  alias Poker.Tables.Commands.{CreateTable}
  alias Poker.Tables.Projections.{Table}

  def create_table(creator, settings_attrs \\ %{}) do
    table_uuid = Ecto.UUID.generate()
    settings_uuid = Ecto.UUID.generate()

    settings_attrs =
      settings_attrs
      |> Map.put(:settings_uuid, settings_uuid)
      |> Map.put(:table_uuid, table_uuid)

    command_attrs = %{
      table_uuid: table_uuid,
      creator_id: creator.id,
      settings: settings_attrs
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateTable.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      Poker.Repo.find_by_id(Table, table_uuid)
    end
  end
end
