defmodule Poker.Repo.Migrations.AddLevelStartedAtToTournaments do
  use Ecto.Migration

  def change do
    alter table(:tournaments) do
      add :level_started_at, :utc_datetime_usec
    end
  end
end
