defmodule Poker.Repo.Migrations.AddPausedStatusToTableList do
  use Ecto.Migration

  def up do
    # Add 'paused' value to the table_status enum type
    # Note: This must run outside a transaction in PostgreSQL
    execute "ALTER TYPE table_status ADD VALUE 'paused' AFTER 'live'"
  end

  def down do
    # Removing enum values is not straightforward in PostgreSQL
    # You would need to recreate the enum type without the value
    # For now, we'll leave it as a no-op since removing enum values
    # requires more complex migration steps
    :ok
  end
end
