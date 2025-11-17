defmodule Poker.Repo.Migrations.CreateTableHandPots do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE pot_type AS ENUM ('main', 'side')",
      "DROP TYPE pot_type"
    )

    create table(:table_hand_pots, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, references(:table_hands, type: :uuid, on_delete: :delete_all), null: false
      add :type, :pot_type, null: false
      add :total_amount, :integer, null: false, default: 0

      timestamps()
    end

    create index(:table_hand_pots, [:hand_id])
  end
end
