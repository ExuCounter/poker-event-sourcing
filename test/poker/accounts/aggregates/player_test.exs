defmodule Poker.Accounts.Aggregates.PlayerTest do
  use Poker.DataCase

  alias Poker.Accounts.Events.{PlayerRegistered}

  describe "register user" do
    test "should succeed when valid" do
      email = Faker.Internet.email()

      {:ok, player} = Poker.Accounts.register_player(%{email: email})

      assert player.email == email

      assert_receive_event(Poker.App, PlayerRegistered, fn event ->
        assert event.email == player.email
        assert event.id == player.id
      end)
    end
  end
end
