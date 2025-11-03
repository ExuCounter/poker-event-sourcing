defmodule Poker.Tables.Projectors.TableSettings do
  use Commanded.Projections.Ecto,
    name: "Tables.Projectors.TableSettings",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Tables.Events.TableSettingsCreated{} = created, fn multi ->
    Ecto.Multi.insert(multi, :table_settings, %Poker.Tables.Projections.TableSettings{
      id: created.id,
      table_id: created.table_id,
      small_blind: created.small_blind,
      big_blind: created.big_blind,
      starting_stack: created.starting_stack,
      timeout_seconds: created.timeout_seconds
    })
  end)
end
