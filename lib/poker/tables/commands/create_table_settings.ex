defmodule Poker.Tables.Commands.CreateTableSettings do
  @derive Jason.Encoder
  use Poker, :schema

  embedded_schema do
    field :small_blind, :integer
    field :big_blind, :integer
    field :starting_stack, :integer
    field :timeout_seconds, :integer
    field :table_type, Ecto.Enum, values: [:six_max]
  end

  def changeset(_settings, attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [
      :small_blind,
      :big_blind,
      :starting_stack,
      :timeout_seconds,
      :table_type
    ])
    |> Ecto.Changeset.validate_required([
      :small_blind,
      :big_blind,
      :starting_stack,
      :timeout_seconds,
      :table_type
    ])
    |> Ecto.Changeset.validate_number(:small_blind, greater_than: 0)
    |> Ecto.Changeset.validate_number(:big_blind, greater_than: 0)
    |> Ecto.Changeset.validate_number(:starting_stack, greater_than: 0)
    |> Ecto.Changeset.validate_number(:timeout_seconds, greater_than: 0)
  end
end
