defmodule Poker.CashGames.Projectors.CashGame do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  import Ecto.Query

  alias Poker.CashGames.Events.{CashGameCreated, CashGameClosed}
  alias Poker.CashGames.Projections.CashGame

  project(%CashGameCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :cash_game, %CashGame{
      id: event.cash_game_id,
      table_id: event.table_id,
      creator_id: event.creator_id,
      code: event.code,
      small_blind: event.small_blind,
      big_blind: event.big_blind,
      min_buyin: event.min_buyin,
      max_buyin: event.max_buyin,
      table_type: event.table_type
    })
  end)

  project(%CashGameClosed{cash_game_id: id}, _metadata, fn multi ->
    Ecto.Multi.delete_all(
      multi,
      :cash_game,
      from(cash_game in CashGame, where: cash_game.id == ^id)
    )
  end)

  def after_update(%CashGameCreated{}, _metadata, _changes) do
    Poker.CashGames.PubSub.broadcast_cash_games_list(:cash_game_created)
    :ok
  end

  def after_update(%CashGameClosed{}, _metadata, _changes) do
    Poker.CashGames.PubSub.broadcast_cash_games_list(:cash_game_closed)
    :ok
  end

  def after_update(_event, _metadata, _changes), do: :ok
end
