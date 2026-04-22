defmodule Poker.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets, primary_key: false) do
      add :player_id, :uuid, primary_key: true
      add :balance, :bigint, null: false, default: 0
      add :reserved, :bigint, null: false, default: 0

      timestamps()
    end
  end
end
