defmodule Poker.CashGames.Projectors.CashGameTest do
  use Poker.DataCase

  alias Poker.CashGames.Projectors.CashGame, as: Projector
  alias Poker.CashGames.Projections.CashGame
  alias Poker.CashGames.Events.CashGameCreated

  defp metadata do
    %{
      handler_name: "cash_game_test",
      event_number: :erlang.unique_integer([:positive, :monotonic])
    }
  end

  describe "CashGameCreated event" do
    test "inserts cash game with all fields" do
      cash_game_id = Ecto.UUID.generate()
      table_id = Ecto.UUID.generate()
      creator_id = Ecto.UUID.generate()

      event = %CashGameCreated{
        cash_game_id: cash_game_id,
        table_id: table_id,
        creator_id: creator_id,
        small_blind: 10,
        big_blind: 20,
        min_buyin: 400,
        max_buyin: 2000,
        table_type: :six_max
      }

      :ok = Projector.handle(event, metadata())

      cash_game = Repo.get(CashGame, cash_game_id)

      assert cash_game.id == cash_game_id
      assert cash_game.table_id == table_id
      assert cash_game.creator_id == creator_id
      assert cash_game.small_blind == 10
      assert cash_game.big_blind == 20
      assert cash_game.min_buyin == 400
      assert cash_game.max_buyin == 2000
      assert cash_game.table_type == :six_max
    end
  end
end
