defmodule Poker.Accounts.Queries do
  @moduledoc """
  Ecto query builders for Accounts schemas.
  """

  import Ecto.Query

  alias Poker.Accounts.Schemas.User

  def base, do: User

  def by_id(query \\ base(), id) do
    where(query, [u], u.id == ^id)
  end

  def guests(query \\ base()) do
    where(query, [u], u.is_guest == true)
  end

  def inactive_since(query \\ base(), %DateTime{} = cutoff) do
    where(query, [u], not is_nil(u.last_active_at) and u.last_active_at < ^cutoff)
  end
end
