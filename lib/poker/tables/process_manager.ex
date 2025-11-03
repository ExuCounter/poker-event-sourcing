defmodule Poker.Tables.ProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: Poker.App,
    name: "Poker.Tables.ProcessManager",
    consistency: :strong

  alias Poker.Tables.Events.{TableCreated}
  alias Poker.Tables.Commands.{CreateTableSettings}

  @derive Jason.Encoder
  defstruct []

  def interested?(%TableCreated{id: table_id} = event, _metadata) do
    {:start, table_id}
  end

  def interested?(_event, _metadata), do: false

  def handle(%Poker.Tables.ProcessManager{}, %TableCreated{settings: settings} = event) do
    struct(CreateTableSettings, settings)
  end
end
