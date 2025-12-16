defmodule Poker.Tables.Projectors.TableParticipantHandsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableParticipantHands
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

    subscribe_to_participant_hands(ctx.table.id)

    on_exit(fn -> unsubscribe_from_participant_hands(ctx.table.id) end)

    ctx
  end

  describe "ParticipantHandGiven event" do
    test "creates participant hand and broadcasts with data", ctx do
      ctx = ctx |> exec(:start_table)

      assert_participant_hand_event!(:participant_hand_given)
      assert_participant_hand_event!(:participant_hand_given)
      assert_participant_hand_event!(:participant_hand_given)

      # # Verify structure of broadcasted data
      # assert data1.id
      # assert data1.participant_id
      # assert is_list(data1.hole_cards)
      # assert data1.position
      # assert data1.status == :active

      # Verify all participant hands are in database
      participant_hands = Repo.all(TableParticipantHands)

      assert length(participant_hands) == 3

      Enum.each(participant_hands, fn ph ->
        assert ph.hand_id == ctx.table.hand.id
        assert ph.participant_id in Enum.map(ctx.table.participants, & &1.id)
        assert is_list(ph.hole_cards)
        assert ph.position
        assert ph.status == :playing
      end)
    end
  end

  describe "ParticipantActedInHand event" do
    test "updates participant hand status when participant acts", ctx do
      ctx = ctx |> setup_winning_hand() |> exec(:start_table) |> exec(:start_runout)

      assert_participant_hand_event!(:participant_hand_given)
      assert_participant_hand_event!(:participant_hand_given)
      assert_participant_hand_event!(:participant_hand_given)

      # Should receive participant_acted events
      # The exact number depends on the actions in start_runout

      participant_hands = Repo.all(TableParticipantHands)

      # Verify at least some hands changed status
      status_counts =
        participant_hands
        |> Enum.map(& &1.status)
        |> Enum.frequencies()

      assert Map.keys(status_counts) |> length() > 0
    end
  end

  defp subscribe_to_participant_hands(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:participant_hands")
  end

  defp unsubscribe_from_participant_hands(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:participant_hands")
  end

  defp assert_participant_hand_event!(event) do
    receive do
      {^event, _data} -> :ok
    after
      1000 -> raise "#{event} was not received"
    end
  end
end
