defmodule Poker.Repo.Migrations.AddAdminRoleToUsers do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE user_role ADD VALUE 'admin'")
  end

  def down do
    execute("""
    DELETE FROM users WHERE role = 'admin'
    """)

    execute("""
    ALTER TYPE user_role RENAME TO user_role_old
    """)

    execute("""
    CREATE TYPE user_role AS ENUM ('player')
    """)

    execute("""
    ALTER TABLE users ALTER COLUMN role TYPE user_role USING role::text::user_role
    """)

    execute("""
    DROP TYPE user_role_old
    """)
  end
end
