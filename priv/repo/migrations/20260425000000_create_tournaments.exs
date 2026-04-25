defmodule Poker.Repo.Migrations.CreateTournaments do
  use Ecto.Migration

  def change do
    create table(:tournaments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :creator_id, :binary_id, null: false
      add :status, :string, null: false, default: "registering"
      add :speed, :string, null: false
      add :buy_in, :integer, null: false
      add :starting_stack, :integer, null: false
      add :table_type, :string, null: false
      add :max_players, :integer, null: false
      add :registered_count, :integer, null: false, default: 0
      add :players_remaining, :integer, null: false, default: 0
      add :current_level, :integer, null: false, default: 1
      add :prize_pool, :integer, null: false, default: 0
      add :player_ids, {:array, :binary_id}, null: false, default: []

      timestamps()
    end

    execute "CREATE TYPE game_mode AS ENUM ('cash_game', 'tournament')", "DROP TYPE game_mode"

    alter table(:table_list) do
      add :game_mode, :game_mode, default: "cash_game"
      add :source_id, :binary_id
    end

    create index(:table_list, [:source_id])
  end
end
