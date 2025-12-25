defmodule Poker.Tables.TableTest do
  use Poker.DataCase
  alias Poker.Tables.Projections.Table
  import Poker.DeckFixtures

  test "test", ctx do
    ctx =
      ctx
      |> exec(:add_participants, generate_players: 2)
      |> exec(:start_table)
      |> exec(:start_runout)
  end
end
