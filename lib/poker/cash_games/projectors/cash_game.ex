defmodule Poker.CashGames.Projectors.CashGame do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.CashGames.Events.CashGameCreated
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
end
