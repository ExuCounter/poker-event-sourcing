defmodule Poker.Repo.Migrations.AddTableTypeEnumValues do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE table_type ADD VALUE IF NOT EXISTS 'two_max'")
    execute("ALTER TYPE table_type ADD VALUE IF NOT EXISTS 'three_max'")
    execute("ALTER TYPE table_type ADD VALUE IF NOT EXISTS 'four_max'")
  end

  def down do
    # PostgreSQL does not support removing values from an enum type
  end
end
