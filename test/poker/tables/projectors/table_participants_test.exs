defmodule Poker.Tables.Projectors.TableParticipantsTest do
  use Poker.DataCase, async: false
  alias Poker.Tables.Projections.TableParticipants
  import Poker.DeckFixtures

  setup do
    Mox.set_mox_global()
  end

  setup ctx do
    ctx = ctx |> produce(:table)

    subscribe_to_participants(ctx.table.id)

    on_exit(fn -> unsubscribe_from_participants(ctx.table.id) end)

    ctx
  end

  describe "ParticipantJoined event" do
    test "creates a new participant with correct values", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 1)

      participant_id = hd(ctx.table.participants).id

      assert_participant_event!(participant_id, :participant_joined)

      participant = Repo.get(TableParticipants, participant_id)

      assert participant.id == participant_id
      assert participant.table_id == ctx.table.id
      assert participant.player_id
      assert participant.chips == ctx.table.settings.starting_stack
      assert participant.status == :active
      assert participant.is_sitting_out == false
    end

    test "creates multiple participants", ctx do
      ctx = ctx |> exec(:add_participants, generate_players: 3)

      assert_participant_event!(hd(ctx.table.participants).id, :participant_joined)
      assert_participant_event!(Enum.at(ctx.table.participants, 1).id, :participant_joined)
      assert_participant_event!(Enum.at(ctx.table.participants, 2).id, :participant_joined)

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

      assert_participant_event!(Enum.at(ctx.table.participants, 1).id, :participant_busted)
      assert_participant_event!(Enum.at(ctx.table.participants, 2).id, :participant_busted)

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

  defp subscribe_to_participants(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:participants")
  end

  defp unsubscribe_from_participants(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:participants")
  end

  defp assert_participant_event!(participant_id, event) do
    receive do
      {:participant_updated, ^participant_id, ^event} -> :ok
    after
      1000 -> raise "#{event} was not received for participant #{participant_id}"
    end
  end
end
