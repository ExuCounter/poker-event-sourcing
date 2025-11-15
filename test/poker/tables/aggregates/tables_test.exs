defmodule Poker.Accounts.Aggregates.TablesTest do
  use Poker.DataCase

  def aggregate_table(table_id) do
    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Tables.Aggregates.Table,
      "table-" <> table_id
    )
  end

  describe "create table" do
    test "should succeed when valid", ctx do
      ctx = ctx |> produce(:player)

      table_settings_params = %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }

      ctx = ctx |> exec(:create_table, settings: table_settings_params)

      table_settings = ctx.table_settings

      assert table_settings.small_blind == table_settings_params.small_blind
      assert table_settings.big_blind == table_settings_params.big_blind
      assert table_settings.starting_stack == table_settings_params.starting_stack
      assert table_settings.timeout_seconds == table_settings_params.timeout_seconds
    end
  end

  describe "add table participants" do
    test "should succeed", ctx do
      ctx =
        ctx
        |> rebind([player: :player1], &produce(&1, :table))
        |> rebind([player: :player2], &produce(&1, :player))

      ctx = ctx |> exec(:add_participants, players: [ctx.player2])

      player1_id = ctx.player1.id
      player2_id = ctx.player2.id

      assert [
               %{
                 player_id: ^player1_id
               },
               %{
                 player_id: ^player2_id
               }
             ] = ctx.participants
    end
  end

  describe "start table" do
    test "should give players initial cards and start the hand", ctx do
      ctx =
        ctx
        |> rebind([player: :player1], &produce(&1, :player))
        |> rebind([player: :player2], &produce(&1, :player))

      ctx =
        ctx |> exec(:add_participants, players: [ctx.player1, ctx.player2]) |> exec(:start_table)

      [participant_hand1, participant_hand2, participant_hand3] = ctx.participant_hands

      assert [
               %{
                 rank: _,
                 suit: _
               },
               %{
                 rank: _,
                 suit: _
               }
             ] = participant_hand1.hole_cards

      assert [
               %{
                 rank: _,
                 suit: _
               },
               %{
                 rank: _,
                 suit: _
               }
             ] = participant_hand2.hole_cards

      assert [
               %{
                 rank: _,
                 suit: _
               },
               %{
                 rank: _,
                 suit: _
               }
             ] = participant_hand3.hole_cards

      assert ctx.table.status == :live
    end

    test "should fail if table is already started", ctx do
      ctx = ctx |> produce(table: [:live])

      assert {:error, :table_already_started} = Poker.Tables.start_table(ctx.table)
    end
  end

  describe "participant actions" do
    test "raise", ctx do
      ctx =
        ctx
        |> rebind([player: :player1], &produce(&1, :player))
        |> rebind([player: :player2], &produce(&1, :player))
        |> rebind([player: :player3], &produce(&1, :player))

      ctx =
        ctx
        |> exec(:create_table)
        |> exec(:add_participants, players: [ctx.player1, ctx.player2, ctx.player3])
        |> exec(:start_table)

      assert ctx.table_hand.current_round == :pre_flop

      ctx = ctx |> exec(:raise_hand, amount: 100)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)

      ctx.participants |> Enum.all?(fn participant -> assert participant.chips == 900 end)

      assert ctx.table_hand.current_round == :flop

      ctx = ctx |> exec(:raise_hand, amount: 200)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)

      assert ctx.table_hand.current_round == :turn

      ctx = ctx |> exec(:raise_hand, amount: 700)
      ctx = ctx |> exec(:call_hand)
      ctx = ctx |> exec(:call_hand)
      _ctx = ctx |> exec(:call_hand)
    end
  end
end
