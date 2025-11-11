defmodule Poker.Repo.Migrations.CreateTableParticipants do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE participant_status AS ENUM ('active', 'folded')",
      "DROP TYPE participant_status"
    )

    create table(:table_participants, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :player_id, references(:players, type: :uuid, on_delete: :delete_all), null: false
      add :table_id, references(:tables, type: :uuid, on_delete: :delete_all), null: false
      add :chips, :integer, null: false
      add :status, :participant_status, null: false, default: "active"
      add :seat_number, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:table_participants, [:player_id])
    create index(:table_participants, [:table_id])
    create unique_index(:table_participants, [:table_id, :seat_number])
    create unique_index(:table_participants, [:table_id, :player_id])
  end
end
