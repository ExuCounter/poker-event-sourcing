defmodule Poker.Repo.Migrations.AddGuestFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_guest, :boolean, default: false, null: false
      add :last_active_at, :utc_datetime
    end

    create index(:users, [:is_guest, :last_active_at])
  end
end
