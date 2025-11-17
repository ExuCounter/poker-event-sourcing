defmodule Poker.Repo.Migrations.CreateTableHandPotEligibilities do
  use Ecto.Migration

  def change do
    create table(:table_hand_pot_eligibilities, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :pot_id, references(:table_hand_pots, type: :uuid, on_delete: :delete_all), null: false
      add :participant_id, references(:table_participants, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:table_hand_pot_eligibilities, [:pot_id])
    create index(:table_hand_pot_eligibilities, [:participant_id])
    create unique_index(:table_hand_pot_eligibilities, [:pot_id, :participant_id])
  end
end
