defmodule Poker.CashGames do
  @moduledoc """
  CashGames context - public API for cash game operations.

  Orchestrates between CashGame aggregate, Wallet, and Tables contexts.
  """

  alias Poker.CashGames.Commands.{CreateCashGame, CloseCashGame}
  alias Poker.CashGames.Queries

  @doc """
  Creates a new cash game.
  This will also create the associated table via ProcessManager.
  """
  def create_cash_game(creator_id, attrs) do
    cash_game_id = UUIDv7.generate()
    table_id = UUIDv7.generate()

    command_attrs =
      Map.merge(attrs, %{
        cash_game_id: cash_game_id,
        table_id: table_id,
        creator_id: creator_id
      })

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CreateCashGame.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      {:ok, %{cash_game_id: cash_game_id, table_id: table_id}}
    end
  end

  @doc """
  Joins a cash game with a specified buy-in amount.
  Reserves funds from wallet and joins the table.
  """
  def join_cash_game(cash_game_id, player_id, buyin_amount) do
    with {:ok, cash_game} <- get_cash_game(cash_game_id),
         :ok <- validate_buyin(cash_game, buyin_amount),
         :ok <- Poker.Wallet.reserve_funds(player_id, cash_game_id, buyin_amount),
         {:ok, participant_id} <-
           Poker.Tables.join_participant(cash_game.table_id, player_id, %{
             starting_stack: buyin_amount
           }) do
      {:ok, participant_id}
    end
  end

  @doc """
  Leaves a cash game and releases funds to wallet.
  The final_chips is the amount of chips the player is leaving with.
  """
  def leave_cash_game(cash_game_id, player_id, final_chips) do
    Poker.Wallet.release_funds(player_id, cash_game_id, final_chips)
  end

  @doc """
  Closes a cash game manually.
  """
  def close_cash_game(cash_game_id) do
    command_attrs = %{cash_game_id: cash_game_id}

    with {:ok, command} <- Poker.Repo.validate_changeset(command_attrs, &CloseCashGame.changeset/1),
         :ok <- Poker.App.dispatch(command, consistency: :strong) do
      :ok
    end
  end

  def get_cash_game(cash_game_id) do
    case Queries.by_id(cash_game_id) |> Poker.Repo.one() do
      nil -> {:error, :cash_game_not_found}
      cash_game -> {:ok, cash_game}
    end
  end

  def get_cash_game_by_table(table_id) do
    case Queries.by_table_id(table_id) |> Poker.Repo.one() do
      nil -> {:error, :cash_game_not_found}
      cash_game -> {:ok, cash_game}
    end
  end

  def list_cash_games do
    Queries.base()
    |> Queries.with_table_status()
    |> Queries.order_by_newest()
    |> Poker.Repo.all()
  end

  defp validate_buyin(cash_game, amount) do
    cond do
      amount < cash_game.min_buyin -> {:error, :buyin_too_low}
      amount > cash_game.max_buyin -> {:error, :buyin_too_high}
      true -> :ok
    end
  end
end
