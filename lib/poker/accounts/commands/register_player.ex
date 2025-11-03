defmodule Poker.Accounts.Commands.RegisterPlayer do
  use Poker, :schema

  embedded_schema do
    field :player_uuid, :string
    field :email, :string
  end

  def register_changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:email, :player_uuid])
    |> validate_required(:email)
  end

  def validate(attrs) do
    changeset = register_changeset(attrs)

    if changeset.valid? do
      Ecto.Changeset.apply_changes(changeset)
    else
      {:error, changeset}
    end
  end
end
