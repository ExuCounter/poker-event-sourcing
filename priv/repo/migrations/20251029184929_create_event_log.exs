defmodule Poker.Repo.Migrations.CreateEventLog do
  use Ecto.Migration

  def change do
    create table(:event_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :aggregate_id, :uuid, null: false
      add :event_type, :string, null: false
      add :data, :map, null: false, default: %{}
      add :version, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:event_log, [:aggregate_id])
    create index(:event_log, [:event_type])
    create unique_index(:event_log, [:aggregate_id, :version])
  end
end
