defmodule Poker.Repo.Migrations.DropUnusedProjectionTables do
  use Ecto.Migration

  def change do
    execute(
      """
      TRUNCATE TABLE
        table_pot_winners,
        table_pots,
        tables,
        table_participants,
        table_participant_hands,
        table_rounds,
        table_list,
        table_lobby,
        projection_versions
      RESTART IDENTITY
      CASCADE;
      """,
      ""
    )
  end
end
