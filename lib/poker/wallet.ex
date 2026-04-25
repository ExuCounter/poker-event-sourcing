defmodule Poker.Wallet do
  @moduledoc """
  Wallet context - public API for player wallet operations.

  Manages player funds using a Reserve/Release pattern:
  - Players deposit funds to their wallet
  - When joining a game, funds are reserved
  - When leaving a game, funds are released (with winnings/losses applied)
  """

  alias Poker.Wallet.Commands.{
    CreateWallet,
    DepositFunds,
    ReserveFunds,
    ReleaseFunds
  }

  @doc """
  Creates a wallet for a player.
  Called when a player first needs a wallet (e.g., on registration or first deposit).
  """
  def create_wallet(player_id, opts \\ []) do
    initial_balance = Keyword.get(opts, :initial_balance, 0)
    command_attrs = %{player_id: player_id, initial_balance: initial_balance}

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateWallet.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  @doc """
  Deposits funds into a player's wallet.
  """
  def deposit_funds(player_id, amount) do
    command_attrs = %{
      player_id: player_id,
      amount: amount
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &DepositFunds.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  @doc """
  Reserves funds for a game (cash game or tournament).
  Called when a player joins a game.
  """
  def reserve_funds(player_id, game_id, amount) do
    command_attrs = %{
      player_id: player_id,
      game_id: game_id,
      amount: amount
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &ReserveFunds.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  @doc """
  Releases funds from a game reservation.
  Called when a player leaves a game with their final chip count.

  - `final_amount` is the chips the player is cashing out with (including winnings/losses)
  """
  def release_funds(player_id, game_id, final_amount) do
    command_attrs = %{
      player_id: player_id,
      game_id: game_id,
      final_amount: final_amount
    }

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &ReleaseFunds.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  @doc """
  Gets a player's wallet projection.
  Returns {:ok, wallet} or {:error, :wallet_not_found}.
  """
  def get_wallet(player_id) do
    case Poker.Repo.get(Poker.Wallet.Projections.Wallet, player_id) do
      nil -> {:error, :wallet_not_found}
      wallet -> {:ok, wallet}
    end
  end
end
