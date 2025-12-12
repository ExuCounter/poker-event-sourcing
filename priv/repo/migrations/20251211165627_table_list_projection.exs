defmodule Poker.Repo.Migrations.TableListProjection do
  use Ecto.Migration

  def change do
    create_enum = "CREATE TYPE table_status AS ENUM ('waiting', 'live', 'finished')"
    drop_enum = "DROP TYPE table_status"

    execute(create_enum, drop_enum)

    create table(:table_list, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :seats_count, :integer, null: false
      add :seated_count, :integer, default: 0
      add :status, :string, null: false

      timestamps()
    end
  end
end
