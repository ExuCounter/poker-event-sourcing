defmodule Poker.CashGames.Queries do
  @moduledoc """
  Ecto query builders for CashGames projections.
  """

  import Ecto.Query

  alias Poker.CashGames.Projections.CashGame
  alias Poker.Tables.Projections.TableList

  def base, do: CashGame

  def by_id(query \\ base(), id) do
    where(query, [cash_game], cash_game.id == ^id)
  end

  def by_table_id(query \\ base(), table_id) do
    where(query, [cash_game], cash_game.table_id == ^table_id)
  end

  def by_code(query \\ base(), code) do
    where(query, [cash_game], cash_game.code == ^code)
  end

  def with_table_status(query \\ base()) do
    from(cash_game in query,
      join: table_list in TableList,
      on: table_list.id == cash_game.table_id,
      select_merge: %{
        table_status: table_list.status,
        seated_count: table_list.seated_count,
        seats_count: table_list.seats_count
      }
    )
  end

  def order_by_newest(query \\ base()) do
    order_by(query, [cash_game], desc: cash_game.inserted_at)
  end
end
