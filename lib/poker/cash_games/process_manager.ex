defmodule Poker.CashGames.ProcessManager do
  @moduledoc """
  Process manager that orchestrates cash game table creation.

  When a cash game is created, this PM creates the associated table.
  """

  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.CashGames.ProcessManager",
    consistency: :strong

  alias Poker.CashGames.Events.{
    CashGameCreated,
    CashGameClosed
  }

  alias Poker.Tables.Commands.{CreateTable, CreateTableSettings}

  @derive Jason.Encoder
  defstruct [:id, :table_id]

  def interested?(%CashGameCreated{id: id}, _metadata), do: {:start, id}
  def interested?(%CashGameClosed{id: id}, _metadata), do: {:stop, id}
  def interested?(_event, _metadata), do: false

  def handle(%__MODULE__{}, %CashGameCreated{} = event) do
    %CreateTable{
      table_id: event.table_id,
      creator_id: event.creator_id,
      creator_participant_id: UUIDv7.generate(),
      settings_id: UUIDv7.generate(),
      settings: %CreateTableSettings{
        small_blind: event.small_blind,
        big_blind: event.big_blind,
        starting_stack: event.max_buyin,
        timeout_seconds: 30,
        table_type: event.table_type
      }
    }
  end

  def apply(%__MODULE__{} = state, %CashGameCreated{id: id, table_id: table_id}) do
    %__MODULE__{state | id: id, table_id: table_id}
  end

  def apply(%__MODULE__{} = state, _event), do: state
end
