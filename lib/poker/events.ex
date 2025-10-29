defmodule Poker.Events do
  use Boundary, deps: [Poker.Repo], exports: [Schemas.Event]

  @moduledoc """
  The Events context for event sourcing and event logging.
  """

  import Ecto.Query, warn: false
  alias Poker.Repo

  alias Poker.Events.Schemas.Event

  @doc """
  Creates an event log entry.

  ## Examples

      iex> create_event(%{aggregate_id: "...", event_type: "user_created", data: %{}, version: 1})
      {:ok, %Event{}}

      iex> create_event(%{})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs) do
    attrs
    |> Event.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Gets all events for a given aggregate_id, ordered by version.

  ## Examples

      iex> list_events_by_aggregate("aggregate-uuid")
      [%Event{}, ...]

  """
  def list_events_by_aggregate(aggregate_id) do
    Event
    |> where([e], e.aggregate_id == ^aggregate_id)
    |> order_by([e], asc: e.version)
    |> Repo.all()
  end

  @doc """
  Gets events by event_type.

  ## Examples

      iex> list_events_by_type("user_created")
      [%Event{}, ...]

  """
  def list_events_by_type(event_type) do
    Event
    |> where([e], e.event_type == ^event_type)
    |> order_by([e], desc: e.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single event by id.

  ## Examples

      iex> get_event("event-uuid")
      %Event{}

      iex> get_event("invalid")
      nil

  """
  def get_event(id) do
    Repo.get(Event, id)
  end
end
