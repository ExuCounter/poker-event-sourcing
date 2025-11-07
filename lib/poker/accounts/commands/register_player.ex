defmodule Poker.Accounts.Commands.RegisterPlayer do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :email, :string
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:email, :player_id])
    |> validate_required(:email)
  end
end
