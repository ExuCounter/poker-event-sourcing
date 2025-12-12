defmodule Poker.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    create_enum = "CREATE TYPE user_role AS ENUM ('player')"
    drop_enum = "DROP TYPE user_role"

    execute(create_enum, drop_enum)

    alter table(:users) do
      add :role, :user_role, null: false, default: "player"
    end
  end
end
