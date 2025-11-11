defmodule Poker.Tables.Supervisor do
  use Supervisor

  alias Poker.Tables

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        Tables.Projectors.Table,
        Tables.Projectors.Settings,
        Tables.Projectors.Participant,
        Tables.Projectors.Hand,
        Tables.Projectors.ParticipantHand,
        Tables.Projectors.ParticipantHandAction
        # Tables.ProcessManager
      ],
      strategy: :one_for_one
    )
  end
end
