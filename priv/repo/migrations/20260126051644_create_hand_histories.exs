defmodule Poker.Repo.Migrations.CreateHandHistories do
  use Ecto.Migration

  def change do
    create table(:hand_histories, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add :hand_id, :binary_id, null: false
      add :table_id, :binary_id, null: false
      add :start_version, :integer, null: false
      add :end_version, :integer
      add :initial_state, :binary, null: false

      timestamps()
    end

    create unique_index(:hand_histories, [:hand_id])
    create index(:hand_histories, [:table_id])
  end
end
