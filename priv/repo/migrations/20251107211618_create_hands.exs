defmodule Poker.Repo.Migrations.CreateHands do
  use Ecto.Migration

  def change do
    create table(:table_hands, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :table_id, references(:tables, type: :uuid, on_delete: :delete_all), null: false
      add :dealer_button_id, references(:table_participants, type: :uuid, on_delete: :delete_all), null: false
      add :flop_cards, {:array, :map}, default: []
      add :turn_card, :map
      add :river_card, :map

      timestamps()
    end

    create index(:table_hands, [:table_id])
    create index(:table_hands, [:dealer_button_id])
  end
end
