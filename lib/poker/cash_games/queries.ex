defmodule Poker.CashGames.Queries do
  @moduledoc """
  Ecto query builders for CashGames projections.
  """

  import Ecto.Query

  alias Poker.CashGames.Projections.CashGame

  def base, do: CashGame

  def by_id(query \\ base(), id) do
    where(query, [c], c.id == ^id)
  end

  def by_table_id(query \\ base(), table_id) do
    where(query, [c], c.table_id == ^table_id)
  end

  def by_status(query \\ base(), status) do
    where(query, [c], c.status == ^status)
  end

  def order_by_newest(query \\ base()) do
    order_by(query, [c], desc: c.inserted_at)
  end
end
