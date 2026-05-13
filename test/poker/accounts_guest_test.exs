defmodule Poker.AccountsGuestTest do
  use Poker.DataCase

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.User
  alias Poker.Wallet

  describe "register_guest/0" do
    test "creates a confirmed guest with synthetic email and 10k wallet" do
      assert {:ok, %User{} = user} = Accounts.register_guest()

      assert user.is_guest
      assert user.confirmed_at
      assert user.onboarded_at == nil
      assert user.last_active_at
      assert user.email =~ ~r/^guest-.*@guests\.local$/
      assert user.nickname =~ ~r/^guest_\d+$/
      assert user.role == :player

      assert {:ok, %{balance: 10_000}} = Wallet.get_wallet(user.id)
    end

    test "Accounts.guest?/1 reflects the flag" do
      {:ok, guest} = Accounts.register_guest()
      assert Accounts.guest?(guest)
      refute Accounts.guest?(%User{is_guest: false})
    end
  end

  describe "upgrade_guest/2" do
    setup do
      {:ok, guest} = Accounts.register_guest()
      %{guest: guest}
    end

    test "promotes a guest into a registered user with credentials", %{guest: guest} do
      attrs = %{
        "email" => "claimed@example.com",
        "password" => "longenoughsecret",
        "password_confirmation" => "longenoughsecret"
      }

      assert {:ok, upgraded} = Accounts.upgrade_guest(guest, attrs)
      assert upgraded.id == guest.id
      refute upgraded.is_guest
      assert upgraded.email == "claimed@example.com"
      assert upgraded.hashed_password
    end

    test "preserves the wallet across upgrade", %{guest: guest} do
      attrs = %{
        "email" => "wallet-keeper@example.com",
        "password" => "longenoughsecret",
        "password_confirmation" => "longenoughsecret"
      }

      {:ok, _} = Accounts.upgrade_guest(guest, attrs)

      assert {:ok, %{balance: 10_000}} = Wallet.get_wallet(guest.id)
    end

    test "rejects upgrades on registered users" do
      {:ok, registered} =
        Accounts.register_user(%{email: "real@example.com", role: :player})

      assert {:error, :not_a_guest} = Accounts.upgrade_guest(registered, %{})
    end
  end

  describe "touch_last_active/1" do
    test "bumps last_active_at on first call" do
      {:ok, user} = Accounts.register_guest()

      :ok =
        user
        |> Ecto.Changeset.change(last_active_at: ~U[2026-01-01 00:00:00Z])
        |> Repo.update()
        |> elem(1)
        |> Accounts.touch_last_active()

      reloaded = Repo.get!(User, user.id)
      assert DateTime.diff(DateTime.utc_now(), reloaded.last_active_at, :second) < 5
    end

    test "is throttled within a minute window" do
      {:ok, user} = Accounts.register_guest()

      thirty_seconds_ago = DateTime.utc_now(:second) |> DateTime.add(-30, :second)

      {:ok, user} =
        user |> Ecto.Changeset.change(last_active_at: thirty_seconds_ago) |> Repo.update()

      :ok = Accounts.touch_last_active(user)

      reloaded = Repo.get!(User, user.id)
      assert DateTime.diff(reloaded.last_active_at, thirty_seconds_ago, :second) == 0
    end
  end

  describe "delete_inactive_guests/1" do
    test "removes guests inactive past the cutoff and leaves fresh and registered alone" do
      {:ok, stale} = Accounts.register_guest()
      {:ok, fresh} = Accounts.register_guest()
      {:ok, real} = Accounts.register_user(%{email: "kept@example.com", role: :player})

      # Backdate "stale" past the cutoff.
      five_days_ago = DateTime.utc_now(:second) |> DateTime.add(-5, :day)
      {:ok, _} = stale |> Ecto.Changeset.change(last_active_at: five_days_ago) |> Repo.update()

      assert Accounts.delete_inactive_guests(3) == 1
      refute Repo.get(User, stale.id)
      assert Repo.get(User, fresh.id)
      assert Repo.get(User, real.id)
    end
  end

  describe "delete_guest_user/1" do
    test "deletes a guest" do
      {:ok, guest} = Accounts.register_guest()
      assert {:ok, _} = Accounts.delete_guest_user(guest)
      refute Repo.get(User, guest.id)
    end

    test "refuses to delete registered users" do
      {:ok, real} = Accounts.register_user(%{email: "keep@example.com", role: :player})
      assert {:error, :not_a_guest} = Accounts.delete_guest_user(real)
      assert Repo.get(User, real.id)
    end
  end
end
