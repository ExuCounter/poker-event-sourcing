defmodule Poker.Repo.Migrations.CreateCashGames do
  use Ecto.Migration

  def change do
    create table(:cash_games, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :table_id, :uuid, null: false
      add :creator_id, :uuid, null: false
      add :status, :string, null: false
      add :small_blind, :integer, null: false
      add :big_blind, :integer, null: false
      add :min_buyin, :integer, null: false
      add :max_buyin, :integer, null: false
      add :table_type, :string, null: false

      timestamps()
    end

    create index(:cash_games, [:table_id], unique: true)
    create index(:cash_games, [:status])
  end
end
