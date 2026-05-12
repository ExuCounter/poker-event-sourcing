defmodule Poker.Repo.Migrations.ConsolidateTableProjections do
  use Ecto.Migration

  def up do
    drop table(:table_list)

    alter table(:table_lobby) do
      remove :small_blind
      remove :big_blind
      remove :starting_stack
      remove :table_type
      remove :creator_id

      add :source_id, :uuid
      add :game_mode, :string
    end

    create index(:table_lobby, [:source_id])
  end

  def down do
    drop index(:table_lobby, [:source_id])

    alter table(:table_lobby) do
      remove :source_id
      remove :game_mode

      add :small_blind, :integer
      add :big_blind, :integer
      add :starting_stack, :integer
      add :table_type, :string
      add :creator_id, :uuid
    end

    create table(:table_list, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :seated_count, :integer
      add :seats_count, :integer
      add :status, :string
      add :game_mode, :string
      add :source_id, :uuid
      timestamps()
    end
  end
end
