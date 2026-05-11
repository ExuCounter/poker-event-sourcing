defmodule Poker.Tournaments.PolicyTest do
  use Poker.DataCase

  alias Poker.Accounts
  alias Poker.Tournaments.Policy

  describe "create_tournament" do
    test "registered users may create tournaments" do
      {:ok, user} = Accounts.register_user(%{email: "real@example.com", role: :player})
      assert :ok = Bodyguard.permit(Policy, :create_tournament, %{user: user}, %{})
    end

    test "guests may not create tournaments" do
      {:ok, guest} = Accounts.register_guest()

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :create_tournament, %{user: guest}, %{})
    end
  end

  describe "register_player" do
    test "guests may register for tournaments" do
      {:ok, guest} = Accounts.register_guest()

      assert :ok =
               Bodyguard.permit(
                 Policy,
                 :register_player,
                 %{user: guest},
                 Ecto.UUID.generate()
               )
    end
  end
end
