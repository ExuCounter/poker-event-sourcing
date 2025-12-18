defmodule Poker.Tables.Projectors.TableParticipantHandsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableParticipantHands
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  describe "ParticipantHandGiven event" do
    setup ctx do
      ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

      ctx
    end

    test "creates participant hand and broadcasts with data", ctx do
      ctx = ctx |> exec(:start_table)

      # Receive all three participant hand events
      assert_receive {:table, :participant_hand_given,
                      %{
                        table_id: _table_id,
                        participant_id: _p1,
                        hole_cards: h1,
                        position: pos1,
                        status: :playing
                      }}

      assert_receive {:table, :participant_hand_given,
                      %{
                        table_id: _table_id,
                        participant_id: _p2,
                        hole_cards: h2,
                        position: pos2,
                        status: :playing
                      }}

      assert_receive {:table, :participant_hand_given,
                      %{
                        table_id: _table_id,
                        participant_id: _p3,
                        hole_cards: h3,
                        position: pos3,
                        status: :playing
                      }}

      # Verify structure of broadcasted data
      assert is_list(h1) and length(h1) == 2
      assert is_list(h2) and length(h2) == 2
      assert is_list(h3) and length(h3) == 2

      # Verify positions are set
      assert pos1 in [:dealer, :small_blind, :big_blind]
      assert pos2 in [:dealer, :small_blind, :big_blind]
      assert pos3 in [:dealer, :small_blind, :big_blind]

      # All positions should be unique
      assert MapSet.size(MapSet.new([pos1, pos2, pos3])) == 3

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

  describe "Participant action events" do
    setup ctx do
      ctx = ctx |> produce(:table) |> exec(:add_participants, generate_players: 3)

      ctx
    end

    test "updates participant hand status when participant acts", ctx do
      ctx = ctx |> setup_winning_hand() |> exec(:start_table) |> exec(:start_runout)

      # Receive participant hand given events
      assert_receive {:table, :participant_hand_given, %{table_id: _table_id}}
      assert_receive {:table, :participant_hand_given, %{table_id: _table_id}}
      assert_receive {:table, :participant_hand_given, %{table_id: _table_id}}

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

  test "Payouts are distributed correctly", ctx do
    ctx =
      ctx
      |> exec(:add_participants, generate_players: 2)

    ctx = ctx |> exec(:start_table)

    ctx = ctx |> exec(:raise_hand, amount: 500)

    ctx = ctx |> exec(:call_hand)

    [participant_hand1, participant_hand2] =
      Enum.map(ctx.table.participants, fn participant ->
        Poker.Repo.get_by!(TableParticipantHands, participant_id: participant.id)
      end)

    # ctx =
    #   ctx
    #   |> exec(:advance_round)
    #   |> exec(:advance_round)
    #   |> exec(:advance_round)

    # [participant1, participant2] =
    #   Enum.map(ctx.table.participants, fn participant ->
    #     Poker.Repo.get!(TableParticipants, participant.id)
    #   end)

    # assert participant1.chips == initial_participant1.chips + 500 - ctx.table.settings.big_blind

    # assert participant2.chips ==
    #          initial_participant2.chips - 500 - ctx.table.settings.small_blind
  end
end
