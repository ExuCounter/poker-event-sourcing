defmodule Poker.Repo.Migrations.CreateTableState do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE participant_position AS ENUM ('dealer', 'small_blind', 'big_blind', 'utg', 'hijack', 'cutoff')",
      "DROP TYPE participant_position"
    )

    execute(
      "CREATE TYPE participant_hand_status AS ENUM ('playing', 'folded', 'all_in')",
      "DROP TYPE participant_hand_status"
    )

    execute(
      "CREATE TYPE participant_status AS ENUM ('active', 'busted')",
      "DROP TYPE participant_status"
    )

    execute(
      "CREATE TYPE round_type AS ENUM ('pre_flop', 'flop', 'turn', 'river')",
      "DROP TYPE round_type"
    )

    execute(
      "CREATE TYPE table_hand_status AS ENUM ('active', 'finished')",
      "DROP TYPE table_hand_status"
    )

    create table(:tables, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :status, :table_status

      timestamps()
    end

    create table(:table_participants, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :table_id, references(:tables, type: :uuid), null: false
      add :player_id, references(:users, type: :uuid), null: false
      add :chips, :integer
      add :status, :participant_status
      add :is_sitting_out, :boolean, default: false

      timestamps()
    end

    create index(:table_participants, [:table_id])

    create table(:table_hands, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :table_id, references(:tables, type: :uuid), null: false
      add :status, :table_hand_status

      timestamps()
    end

    create index(:table_hands, [:table_id])

    create table(:table_rounds, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, references(:table_hands, type: :uuid), null: false
      add :round_type, :round_type
      add :participant_to_act_id, references(:table_participants, type: :uuid)
      add :community_cards, {:array, :map}, default: []

      timestamps()
    end

    create index(:table_rounds, [:hand_id])

    create table(:table_participant_hands, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, references(:table_hands, type: :uuid), null: false
      add :participant_id, references(:table_participants, type: :uuid), null: false
      add :hole_cards, {:array, :map}, default: []
      add :position, :participant_position
      add :status, :participant_hand_status

      timestamps()
    end

    create index(:table_participant_hands, [:hand_id])
    create index(:table_participant_hands, [:participant_id])
    create unique_index(:table_participant_hands, [:hand_id, :participant_id])

    create table(:table_pots, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, references(:table_hands, type: :uuid), null: false
      add :amount, :integer, default: 0

      timestamps()
    end

    create index(:table_pots, [:hand_id])

    create table(:table_pot_winners, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, references(:table_hands, type: :uuid), null: false
      add :pot_id, references(:table_pots, type: :uuid), null: false
      add :participant_id, references(:table_participants, type: :uuid), null: false
      add :amount, :integer

      timestamps()
    end

    create index(:table_pot_winners, [:hand_id])
    create index(:table_pot_winners, [:pot_id])
  end
end
