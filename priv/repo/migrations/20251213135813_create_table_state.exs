defmodule Poker.Repo.Migrations.CreateTableState do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE participant_position AS ENUM ('dealer', 'small_blind', 'big_blind', 'utg', 'utg_plus_one', 'cutoff')",
      "DROP TYPE participant_position"
    )

    execute(
      "CREATE TYPE participant_hand_status AS ENUM ('active', 'folded', 'all_in')",
      "DROP TYPE participant_hand_status"
    )

    execute(
      "CREATE TYPE round_type AS ENUM ('preflop', 'flop', 'turn', 'river')",
      "DROP TYPE round_type"
    )

    create table(:table_state, primary_key: false) do
      add :id, :uuid, null: false
      add :hand_id, :uuid
      add :round_type, :round_type
      add :community_cards, {:array, :string}, default: []
      add :participant_to_act_id, :uuid
      add :pots, :jsonb, default: "[]"
      add :participant_hands, :jsonb, default: "[]"

      timestamps()
    end

    create index(:table_state, [:id], unique: true)
  end
end
