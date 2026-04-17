defmodule Poker.Repo.Migrations.AddNicknameToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :nickname, :string
    end

    # Generate nicknames for existing users from their email
    execute """
    UPDATE users
    SET nickname = CONCAT('user_', SUBSTRING(MD5(RANDOM()::text), 1, 8))
    WHERE nickname IS NULL
    """

    alter table(:users) do
      modify :nickname, :string, null: false
    end

    create unique_index(:users, [:nickname])
  end

  def down do
    drop index(:users, [:nickname])

    alter table(:users) do
      remove :nickname
    end
  end
end
