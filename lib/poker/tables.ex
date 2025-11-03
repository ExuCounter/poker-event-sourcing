defmodule Poker.Tables do
  alias Poker.Tables.Commands.{CreateTable}
  alias Poker.Tables.Projections.{Table}

  def create_table(creator, settings \\ %{}) do
    table_uuid = Ecto.UUID.generate()
    settings_uuid = Ecto.UUID.generate()

    settings =
      settings |> Map.put(:settings_uuid, settings_uuid) |> Map.put(:table_uuid, table_uuid)

    create_table =
      %{}
      |> Map.put(:table_uuid, table_uuid)
      |> Map.put(:creator_id, creator.id)
      |> Map.put(:settings, settings)
      |> CreateTable.validate()

    with :ok <- Poker.App.dispatch(create_table, consistency: :strong) do
      get(Table, table_uuid)
    end
  end

  defp get(schema, uuid) do
    case Poker.Repo.get(schema, uuid) do
      nil -> {:error, :not_found}
      projection -> {:ok, projection}
    end
  end
end
