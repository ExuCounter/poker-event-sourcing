defmodule Poker.CashGames.PolicyTest do
  use Poker.DataCase

  alias Poker.Accounts
  alias Poker.CashGames.Policy

  describe "create_cash_game" do
    test "registered users may create cash games" do
      {:ok, user} = Accounts.register_user(%{email: "real@example.com", role: :player})
      assert :ok = Bodyguard.permit(Policy, :create_cash_game, %{user: user}, %{})
    end

    test "guests may not create cash games" do
      {:ok, guest} = Accounts.register_guest()

      assert {:error, :unauthorized} =
               Bodyguard.permit(Policy, :create_cash_game, %{user: guest}, %{})
    end
  end

  describe "join_cash_game" do
    test "guests may join cash games" do
      {:ok, guest} = Accounts.register_guest()

      assert :ok =
               Bodyguard.permit(Policy, :join_cash_game, %{user: guest}, Ecto.UUID.generate())
    end
  end
end
