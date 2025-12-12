defmodule Poker.Repo.Migrations.CreateTableLobby do
  use Ecto.Migration

  def change do
    create_enum = "CREATE TYPE table_type AS ENUM ('six_max')"
    drop_enum = "DROP TYPE table_type"

    execute(create_enum, drop_enum)

    create table(:table_lobby, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :small_blind, :integer, null: false
      add :big_blind, :integer, null: false
      add :starting_stack, :integer, null: false
      add :table_type, :table_type, null: false
      add :seated_count, :integer, null: false, default: 0
      add :seats_count, :integer, null: false
      add :status, :table_status, null: false

      timestamps()
    end
  end
end
