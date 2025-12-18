defmodule Poker.Tables.Projectors.TableParticipantsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableParticipants
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table)

    ctx
  end

  describe "ParticipantJoined event" do
    test "creates a new participant with correct values", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 1)

      [participant] = ctx.table.participants

      assert_receive {:table, :participant_joined, %{table_id: _table_id, participant_id: participant_id}}

      assert participant_id == participant.id

      db_participant = Repo.get(TableParticipants, participant_id)

      assert db_participant.id == participant_id
      assert db_participant.table_id == ctx.table.id
      assert db_participant.player_id
      assert db_participant.chips == ctx.table.settings.starting_stack
      assert db_participant.status == :active
      assert db_participant.is_sitting_out == false
    end

    test "creates multiple participants", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 3)

      [participant1, participant2, participant3] = ctx.table.participants

      assert_receive {:table, :participant_joined, %{table_id: _table_id, participant_id: participant_id_1}}
      assert_receive {:table, :participant_joined, %{table_id: _table_id, participant_id: participant_id_2}}
      assert_receive {:table, :participant_joined, %{table_id: _table_id, participant_id: participant_id_3}}

      assert participant_id_1 == participant1.id
      assert participant_id_2 == participant2.id
      assert participant_id_3 == participant3.id

      participants = Repo.all(TableParticipants)

      assert length(participants) == 3
    end
  end

  # describe "ParticipantSatOut event" do
  #   test "updates is_sitting_out to true", ctx do
  #     ctx = ctx |> exec(:add_participants, generate_players: 1)

  #     participant_id = hd(ctx.table.participants).id

  #     ctx = ctx |> exec(:sit_out_participant, participant_id: participant_id)

  #     assert_participant_event!(participant_id, :participant_sat_out)

  #     participant = Repo.get(TableParticipants, participant_id)

  #     assert participant.is_sitting_out == true
  #   end
  # end

  # describe "ParticipantSatIn event" do
  #   test "updates is_sitting_out to false", ctx do
  #     ctx =
  #       ctx
  #       |> exec(:add_participants, generate_players: 1)
  #       |> exec(:sit_out_participant, participant_id: hd(ctx.participants).id)

  #     participant_id = hd(ctx.participants).id

  #     ctx = ctx |> exec(:sit_in_participant, participant_id: participant_id)

  #     assert_participant_event!(participant_id, :participant_sat_in)

  #     participant = Repo.get(TableParticipants, participant_id)

  #     assert participant.is_sitting_out == false
  #   end
  # end

  describe "ParticipantBusted event" do
    test "updates participant status to busted", ctx do
      ctx =
        ctx
        |> exec(:add_participants, generate_players: 3)
        |> setup_winning_hand()
        |> exec(:start_table)
        |> exec(:start_runout)

      [_participant1, participant2, participant3] = ctx.table.participants

      assert_receive {:table, :participant_busted, %{table_id: _table_id, participant_id: participant_id_2}}
      assert_receive {:table, :participant_busted, %{table_id: _table_id, participant_id: participant_id_3}}

      assert participant_id_2 == participant2.id
      assert participant_id_3 == participant3.id

      # Get busted participants
      busted_participants =
        Repo.all(from p in TableParticipants, where: p.status == :busted)

      assert length(busted_participants) == 2

      Enum.each(busted_participants, fn participant ->
        assert participant.status == :busted
      end)
    end
  end

  describe "HandFinished event" do
    test "updates participant chips after hand", ctx do
      ctx =
        ctx
        |> exec(:add_participants, generate_players: 2)
        |> setup_winning_hand()
        |> exec(:start_table)

      participants_before = Repo.all(TableParticipants)

      ctx = ctx |> exec(:start_runout)

      assert_receive {:table, :payouts_distributed, %{table_id: _table_id, hand_id: _hand_id, payouts: payouts}}

      assert length(payouts) > 0

      participants_after = Repo.all(TableParticipants)

      # At least one participant should have different chips
      chips_changed =
        Enum.any?(participants_after, fn p_after ->
          p_before = Enum.find(participants_before, &(&1.id == p_after.id))
          p_after.chips != p_before.chips
        end)

      assert chips_changed
    end
  end
end
