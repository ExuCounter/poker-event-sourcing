defmodule Poker.CommandedHelper do
  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias Poker.Tables

  @handlers [
    Tables.EventHandlers.TableEventBroadcaster,
    Tables.Projectors.TableList,
    Tables.Projectors.TableLobby,
    Tables.Projectors.HandHistory,
    Tables.ProcessManager
  ]

  def start_commanded do
    Enum.each(@handlers, &start_supervised!/1)
  end
end
