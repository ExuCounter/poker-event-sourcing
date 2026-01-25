defmodule Poker.Tables.Supervisor do
  use Supervisor

  alias Poker.Tables

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        # Event handlers (for broadcasting to LiveView)
        Tables.EventHandlers.TableEventBroadcaster,
        # Projectors (for lobby/list views only)
        Tables.Projectors.TableList,
        Tables.Projectors.TableLobby,
        Tables.Projectors.HandHistory,
        # Tables.Projectors.Table,
        # Tables.Projectors.TableParticipants,
        # Process manager (for workflow orchestration)
        Tables.ProcessManager
      ],
      strategy: :one_for_one
    )
  end
end
