defmodule Poker.Repo.Migrations.CreateTableParticipantHands do
  use Ecto.Migration

  def change do
    create table(:table_participant_hands, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :table_id, :uuid, null: false
      add :participant_id, references(:table_participants, type: :uuid, on_delete: :delete_all), null: false
      add :table_hand_id, references(:table_hands, type: :uuid, on_delete: :delete_all), null: false
      add :hole_cards, {:array, :map}, default: []

      timestamps()
    end

    create index(:table_participant_hands, [:table_id])
    create index(:table_participant_hands, [:participant_id])
    create index(:table_participant_hands, [:table_hand_id])
  end
end
