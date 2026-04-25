defmodule Poker.Tournaments.Queries do
  import Ecto.Query

  alias Poker.Tournaments.Projections.Tournament
  alias Poker.Tables.Projections.TableList

  def base, do: Tournament

  def by_id(query \\ base(), id) do
    where(query, [tournament], tournament.id == ^id)
  end

  def order_by_newest(query \\ base()) do
    order_by(query, [tournament], desc: tournament.inserted_at)
  end

  def table_by_source(source_id) do
    from(table_list in TableList,
      where: table_list.source_id == ^source_id
    )
    |> Poker.Repo.one()
  end

  def table_by_id(table_id) do
    from(table_list in TableList,
      where: table_list.id == ^table_id
    )
    |> Poker.Repo.one()
  end
end
