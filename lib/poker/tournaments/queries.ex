defmodule Poker.Tournaments.Queries do
  import Ecto.Query

  alias Poker.Tournaments.Projections.Tournament
  alias Poker.Tables.Projections.TableLobby

  def base, do: Tournament

  def by_id(query \\ base(), id) do
    where(query, [tournament], tournament.id == ^id)
  end

  def by_code(query \\ base(), code) do
    where(query, [tournament], tournament.code == ^code)
  end

  def order_by_newest(query \\ base()) do
    order_by(query, [tournament], desc: tournament.inserted_at)
  end

  def table_by_source(source_id) do
    from(lobby in TableLobby,
      where: lobby.source_id == ^source_id
    )
    |> Poker.Repo.one()
  end

  def table_by_id(table_id) do
    from(lobby in TableLobby,
      where: lobby.id == ^table_id
    )
    |> Poker.Repo.one()
  end
end
