defmodule Poker.Tables.Projectors.Table do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.Table",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Tables.Events.TableCreated{} = created, fn multi ->
    Ecto.Multi.insert(multi, :table, %Poker.Tables.Projections.Table{
      id: created.id,
      creator_id: created.creator_id,
      status: created.status |> String.to_existing_atom()
    })
  end)
end
