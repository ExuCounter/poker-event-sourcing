defmodule Poker.Repo.Migrations.CreateHandSummaries do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE hand_finish_reason AS ENUM ('showdown', 'all_folded', 'all_in_runout')",
      "DROP TYPE hand_finish_reason"
    )

    create table(:hand_summaries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, :binary_id, null: false
      add :table_id, :binary_id, null: false
      add :game_mode, :game_mode, null: false
      add :source_id, :binary_id
      add :pot_total, :integer, null: false, default: 0
      add :finish_reason, :hand_finish_reason
      add :winner_player_id, :binary_id
      add :winner_hand_rank, :string

      timestamps()
    end

    create unique_index(:hand_summaries, [:hand_id])
    create index(:hand_summaries, [:table_id])
    create index(:hand_summaries, [:inserted_at])
  end
end
