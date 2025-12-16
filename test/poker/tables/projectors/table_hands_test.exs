defmodule Poker.Tables.Projectors.TableHandsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableHands
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    subscribe_to_hands(ctx.table.id)

    on_exit(fn -> unsubscribe_from_hands(ctx.table.id) end)

    ctx
  end

  describe "HandStarted event" do
    test "creates a new hand with active status", ctx do
      ctx = ctx |> exec(:start_table)

      hand_id = ctx.table.hand.id

      assert_hand_event!(hand_id, :hand_started)

      hand = Repo.get(TableHands, hand_id)

      assert hand.id == hand_id
      assert hand.table_id == ctx.table.id
      assert hand.status == :active
    end
  end

  describe "HandFinished event" do
    test "updates hand status to finished when hand completes", ctx do
      ctx = ctx |> setup_winning_hand() |> exec(:start_table) |> exec(:start_runout)

      hand_id = ctx.table.hand.id

      assert_hand_event!(hand_id, :hand_finished)

      hand = Repo.get(TableHands, hand_id)

      assert hand.status == :finished
    end
  end

  defp subscribe_to_hands(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:hands")
  end

  defp unsubscribe_from_hands(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:hands")
  end

  defp assert_hand_event!(hand_id, event) do
    receive do
      {:hand_updated, ^hand_id, ^event} -> :ok
    after
      1000 -> raise "#{event} was not received for hand #{hand_id}"
    end
  end
end
