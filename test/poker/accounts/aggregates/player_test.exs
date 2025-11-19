defmodule Poker.Accounts.Aggregates.PlayerTest do
  use Poker.DataCase

  alias Poker.Accounts.Events.{PlayerRegistered}

  def aggregate_player(player_id) do
    Commanded.Aggregates.Aggregate.aggregate_state(
      Poker.App,
      Poker.Accounts.Aggregates.Player,
      "player-" <> player_id
    )
  end

  describe "register user" do
    test "should succeed when valid" do
      email = Faker.Internet.email()

      {:ok, player_id} = Poker.Accounts.register_player(%{email: email})

      player = aggregate_player(player_id)

      assert_receive_event(Poker.App, PlayerRegistered, fn event ->
        assert event.email == player.email
        assert event.id == player.id
      end)
    end
  end
end
