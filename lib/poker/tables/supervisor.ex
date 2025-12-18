defmodule Poker.Tables.Supervisor do
  use Supervisor

  alias Poker.Tables

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        Tables.Projectors.TableList,
        Tables.Projectors.TableLobby,
        Tables.Projectors.Table,
        Tables.Projectors.TableHands,
        Tables.Projectors.TableRounds,
        Tables.Projectors.TableParticipants,
        Tables.Projectors.TableParticipantHands,
        Tables.Projectors.TablePots,
        Tables.Projectors.TablePotWinners,
        Tables.ProcessManager
      ],
      strategy: :one_for_one
    )
  end
end
