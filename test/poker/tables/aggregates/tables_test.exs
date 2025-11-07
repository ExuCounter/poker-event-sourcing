defmodule Poker.Accounts.Aggregates.TablesTest do
  use Poker.DataCase

  alias Poker.Tables.Events.{TableCreated, TableSettingsCreated}

  describe "create table" do
    test "should succeed when valid", ctx do
      ctx = ctx |> produce(:player)

      table_settings_params = %{
        small_blind: 10,
        big_blind: 20,
        starting_stack: 1000,
        timeout_seconds: 90
      }

      {:ok, table} = Poker.Tables.create_table(ctx.player, table_settings_params)

      table = table |> Poker.Repo.preload([:settings, :creator])

      table_settings = table.settings

      assert table_settings.small_blind == table_settings_params.small_blind
      assert table_settings.big_blind == table_settings_params.big_blind
      assert table_settings.starting_stack == table_settings_params.starting_stack
      assert table_settings.timeout_seconds == table_settings_params.timeout_seconds

      assert_receive_event(Poker.App, TableSettingsCreated, fn _settings ->
        :ok
      end)

      assert_receive_event(Poker.App, TableCreated, fn _table ->
        :ok
      end)
    end
  end

  describe "create table participant" do
    test "should succeed", ctx do
      %{player: player1, table: table} = ctx |> produce(:table)

      %{player: player2} = ctx |> produce(:player)

      {:ok, _participant} = Poker.Tables.join_participant(table, player2)

      table = table |> Poker.Repo.preload(:participants)

      player1_id = player1.id
      player2_id = player2.id

      assert [
               %{
                 player_id: ^player1_id
               },
               %{
                 player_id: ^player2_id
               }
             ] = table.participants
    end
  end

  describe "start game" do
    test "should succeed", ctx do
      %{player: player1, table: table} = ctx |> produce(:table)
      %{player: player2} = ctx |> produce(:player)

      {:ok, _participant} = Poker.Tables.join_participant(table, player2)

      {:ok, table} = Poker.Tables.start_table(table)

      table = table |> Poker.Repo.preload([:participants, hands: [:participant_hands]])

      [hand] = table.hands
      [participant_hand1, participant_hand2] = hand.participant_hands

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
             ] = participant_hand1.hole_cards

      assert table.status == :live
    end

    test "should fail if table already started", ctx do
      ctx = ctx |> produce(table: [:live])

      assert {:error, :table_already_started} = Poker.Tables.start_table(ctx.table)
    end
  end
end
