defmodule Poker.Repo.Migrations.EnableUuidExtension do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", "DROP EXTENSION IF EXISTS pgcrypto"
  end
end
