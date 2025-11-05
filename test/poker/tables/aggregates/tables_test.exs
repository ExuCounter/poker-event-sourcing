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
end
