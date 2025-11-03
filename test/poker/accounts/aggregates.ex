defmodule Poker.Accounts.Aggregates.PlayerTest do
  use Poker.DataCase

  alias Poker.Accounts.Events.PlayerRegistered

  describe "register user" do
    test "should succeed when valid" do
      email = "email2222@gmail.com"
      {:ok, player} = Poker.Accounts.register_player(%{email: email})

      dbg(player)

      assert_receive_event(Poker.App, PlayerRegistered, fn event ->
        dbg(event)
        assert event.email == player.email
        assert event.id == player.id
      end)
    end
  end
end
