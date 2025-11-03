defmodule Poker.Tables.Aggregates.TableSettings do
  use Poker, :schema
  alias Poker.Tables.Aggregates.TableSettings

  embedded_schema do
    field :table_id, :binary_id
    field :small_blind, :integer
    field :big_blind, :integer
    field :starting_stack, :integer
    field :timeout_seconds, :integer
  end

  alias Poker.Tables.Commands.{CreateTableSettings}
  alias Poker.Tables.Events.{TableSettingsCreated}

  def execute(%TableSettings{}, %CreateTableSettings{} = create) do
    %TableSettingsCreated{
      id: create.settings_uuid,
      table_id: create.table_uuid,
      small_blind: create.small_blind,
      big_blind: create.big_blind,
      starting_stack: create.starting_stack,
      timeout_seconds: create.timeout_seconds
    }
  end

  # State mutators

  def apply(%TableSettings{} = _table_settings, %TableSettingsCreated{} = created) do
    %TableSettings{
      id: created.id,
      table_id: created.table_id,
      small_blind: created.small_blind,
      big_blind: created.big_blind,
      starting_stack: created.starting_stack,
      timeout_seconds: created.timeout_seconds
    }
  end
end
