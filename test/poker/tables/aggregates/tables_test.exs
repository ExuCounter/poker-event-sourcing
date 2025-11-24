defmodule Poker.Accounts.Aggregates.TablesTest do
  use Poker.DataCase, async: false

  setup do
    Mox.set_mox_global()
  end

  def aggregate_table(table_id) do
    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  describe "create table aggregate" do
    test "should have not_started status when created", ctx do
      ctx = ctx |> produce(:table)

      assert ctx.table.status == :not_started
    end

    test "should belong to creator player", ctx do
      ctx = ctx |> produce(:table)

      assert ctx.table.creator_id == ctx.player.id
    end

    test "should have settings associated", ctx do
      ctx =
        ctx
        |> exec(:create_table,
          settings: %{
            small_blind: 10,
            big_blind: 20,
            starting_stack: 1000,
            timeout_seconds: 90
          }
        )

      assert ctx.table.settings.small_blind == 10
      assert ctx.table.settings.big_blind == 20
      assert ctx.table.settings.starting_stack == 1000
      assert ctx.table.settings.timeout_seconds == 90
    end
  end

  describe "add table participants" do
    test "successfully", ctx do
      [player1, player2] =
        for _ <- 1..2 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx =
        ctx
        |> exec(:create_table, type: :six_max)
        |> exec(:add_participants, players: [player1, player2])

      assert length(ctx.table.participants) == 2

      [participant1, participant2] = ctx.table.participants

      assert participant1.player_id == player1.id
      assert participant1.chips == ctx.table.settings.starting_stack
      assert participant1.seat_number == 1
      assert participant1.status == :active
      assert participant1.is_sitting_out == false

      assert participant2.player_id == player2.id
      assert participant2.chips == ctx.table.settings.starting_stack
      assert participant2.seat_number == 2
      assert participant2.status == :active
      assert participant2.is_sitting_out == false
    end

    test "should fail if table already started", ctx do
      players =
        for _ <- 1..6 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx = ctx |> exec(:add_participants, players: players)
      ctx = ctx |> exec(:start_table)

      %{player: player} = produce(ctx, :player)

      assert {:error, :table_already_started} = Poker.Tables.join_participant(ctx.table, player)
    end

    test "should not allow to join table if full", ctx do
      players =
        for _ <- 1..6 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx =
        ctx
        |> exec(:create_table, type: :six_max)
        |> exec(:add_participants, players: players)

      %{player: player} = produce(ctx, :player)

      assert {:error, :table_full} =
               Poker.Tables.join_participant(ctx.table, player)
    end

    test "should not allow to start table with less than 2 players", ctx do
      ctx = ctx |> exec(:create_table, type: :six_max)

      assert {:error, :not_enough_participants} =
               Poker.Tables.start_table(ctx.table)
    end
  end

  describe "6max table" do
    setup ctx do
      players =
        for _ <- 1..6 do
          %{player: player} = produce(ctx, :player)
          player
        end

      ctx =
        ctx
        |> exec(:create_table, type: :six_max)
        |> exec(:add_participants, players: players)

      dbg(ctx.table.id)
      dbg("=====")

      ctx
    end

    test "should give players initial cards and start the hand", ctx do
      ctx = ctx |> exec(:start_table)

      assert ctx.table.hand.id != nil
      assert ctx.table.round.type == :pre_flop

      assert length(ctx.table.community_cards) == 0
      assert length(ctx.table.participant_hands) == 6

      Enum.each(ctx.table.participant_hands, fn hand ->
        assert length(hand.hole_cards) == 2

        assert hand.position in [
                 :dealer,
                 :small_blind,
                 :big_blind,
                 :cutoff,
                 :utg,
                 :hijack
               ]

        assert Enum.all?(hand.hole_cards, fn card ->
                 Map.has_key?(card, :rank) and Map.has_key?(card, :suit)
               end)
      end)

      assert ctx.table.status == :live
    end

    test "should have blinds posted on start", ctx do
      ctx = ctx |> exec(:start_table)

      assert ctx.positions.small_blind.participant.chips ==
               ctx.table.settings.starting_stack - ctx.table.settings.small_blind

      assert ctx.positions.big_blind.participant.chips ==
               ctx.table.settings.starting_stack - ctx.table.settings.big_blind

      assert ctx.positions.dealer.participant.chips == ctx.table.settings.starting_stack
      assert ctx.positions.cutoff.participant.chips == ctx.table.settings.starting_stack
      assert ctx.positions.hijack.participant.chips == ctx.table.settings.starting_stack

      assert ctx.positions.utg.participant.chips == ctx.table.settings.starting_stack
    end

    test "should calculate pot correctly after first move", ctx do
      ctx = ctx |> exec(:start_table)

      [pot1, pot2] = ctx.table.pots

      assert pot1.amount == ctx.table.settings.small_blind * 2
      assert pot1.bet_amount == ctx.table.settings.small_blind

      assert pot1.contributing_participant_ids == [
               ctx.positions.small_blind.participant.id,
               ctx.positions.big_blind.participant.id
             ]

      assert pot2.amount == ctx.table.settings.big_blind - ctx.table.settings.small_blind
      assert pot2.bet_amount == ctx.table.settings.big_blind
      assert pot2.contributing_participant_ids == [ctx.positions.big_blind.participant.id]
    end

    test "should deal flop after betting round", ctx do
      ctx = ctx |> exec(:start_table)

      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)

      assert ctx.table.round.type == :flop

      assert length(ctx.table.community_cards) == 3
    end

    test "should deal turn after betting round", ctx do
      ctx = ctx |> exec(:start_table) |> exec(:advance_round)

      assert ctx.table.round.type == :flop

      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)

      assert ctx.table.round.type == :turn
      assert length(ctx.table.community_cards) == 4
    end

    test "should deal river after betting round", ctx do
      ctx = ctx |> exec(:start_table) |> exec(:advance_round) |> exec(:advance_round)

      assert ctx.table.round.type == :turn

      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)

      assert ctx.table.round.type == :river
      assert length(ctx.table.community_cards) == 5
    end
  end
end
