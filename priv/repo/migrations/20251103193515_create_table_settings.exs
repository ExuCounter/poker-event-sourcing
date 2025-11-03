defmodule Poker.Repo.Migrations.CreateTableSettings do
  use Ecto.Migration

  def change do
    create table(:table_settings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :table_id, references(:tables, type: :uuid), null: false
      add :small_blind, :integer, null: false
      add :big_blind, :integer, null: false
      add :starting_stack, :integer, null: false
      add :timeout_seconds, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:table_settings, [:table_id])
  end
end
