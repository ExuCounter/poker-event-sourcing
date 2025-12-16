defmodule Poker.Tables.Projectors.TableHands do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.{HandStarted, HandFinished}
  alias Poker.Tables.Projections.TableHands

  import Ecto.Query

  def hand_query(id), do: from(h in TableHands, where: h.id == ^id)

  project(%HandStarted{id: id, table_id: table_id}, fn multi ->
    Ecto.Multi.insert(multi, :hand, %TableHands{
      id: id,
      table_id: table_id,
      status: :active
    })
  end)

  project(%HandFinished{hand_id: hand_id}, fn multi ->
    Ecto.Multi.update_all(multi, :hand, hand_query(hand_id), set: [status: :finished])
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%HandStarted{id: hand_id, table_id: table_id}, _metadata, _changes) do
    broadcast_hand(table_id, hand_id, :hand_started)
  end

  def after_update(%HandFinished{hand_id: hand_id, table_id: table_id}, _metadata, _changes) do
    broadcast_hand(table_id, hand_id, :hand_finished)
  end

  defp broadcast_hand(table_id, hand_id, event) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}:hands",
      {:hand_updated, hand_id, event}
    )

    :ok
  end
end
