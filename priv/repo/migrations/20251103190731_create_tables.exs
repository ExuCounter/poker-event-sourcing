defmodule Poker.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE table_status AS ENUM ('not_started', 'live', 'finished')",
      "DROP TYPE table_status"
    )

    create table(:tables, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :status, :table_status, null: false, default: "not_started"
      add :creator_id, references(:players, type: :uuid), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tables, [:creator_id])
    create index(:tables, [:status])
  end
end
