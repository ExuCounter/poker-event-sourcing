defmodule Poker do
  use Boundary,
    deps: [],
    exports: [Accounts, Accounts.Schemas.User, Accounts.Scope, Events, Events.Schemas.Event]

  def schema do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @primary_key {:id, :binary_id, read_after_writes: true}
      @foreign_key_type :binary_id
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
