defmodule Poker.CashGames.Projectors.CashGame do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.CashGames.Events.{
    CashGameCreated,
    CashGameClosed
  }

  alias Poker.CashGames.Projections.CashGame

  project(%CashGameCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :cash_game, %CashGame{
      id: event.id,
      table_id: event.table_id,
      creator_id: event.creator_id,
      status: event.status,
      small_blind: event.small_blind,
      big_blind: event.big_blind,
      min_buyin: event.min_buyin,
      max_buyin: event.max_buyin,
      table_type: event.table_type
    })
  end)

  project(%CashGameClosed{id: id}, _metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :cash_game,
      from(c in CashGame, where: c.id == ^id),
      set: [status: :closed]
    )
  end)
end
