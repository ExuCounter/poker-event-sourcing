defmodule Poker do
  @moduledoc """
  Poker keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def schema do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @primary_key {:id, UUIDv7.Type, autogenerate: true}
      @foreign_key_type UUIDv7.Type 
    end
  end

  def query do
    quote do
      import Ecto.Query
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
