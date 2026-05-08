defmodule Poker.Repo.Migrations.AddOnboardedAtToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :onboarded_at, :utc_datetime
    end

    execute("UPDATE users SET onboarded_at = confirmed_at WHERE confirmed_at IS NOT NULL")
  end

  def down do
    alter table(:users) do
      remove :onboarded_at
    end
  end
end
