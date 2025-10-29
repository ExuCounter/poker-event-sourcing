defmodule Poker.Events.Schemas.Event do
  use Poker, :schema

  schema "event_log" do
    field :aggregate_id, :binary_id
    field :event_type, :string
    field :data, :map
    field :version, :integer

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating an event log entry.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:aggregate_id, :event_type, :data, :version])
    |> validate_required([:aggregate_id, :event_type, :data, :version])
    |> validate_number(:version, greater_than_or_equal_to: 0)
    |> unique_constraint([:aggregate_id, :version])
  end
end
