defmodule Poker.Tables.Projectors.TablePots do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.PotsRecalculated
  alias Poker.Tables.Projections.TablePots

  import Ecto.Query

  def hand_pots_query(hand_id), do: from(p in TablePots, where: p.hand_id == ^hand_id)

  project(%PotsRecalculated{hand_id: hand_id, pots: pots}, fn multi ->
    # First delete existing pots for this hand (in case of recalculation)
    multi = Ecto.Multi.delete_all(multi, :delete_old_pots, hand_pots_query(hand_id))

    # Then insert new pots
    Enum.reduce(pots, multi, fn pot, acc_multi ->
      Ecto.Multi.insert(
        acc_multi,
        {:insert_pot, pot.id},
        %TablePots{
          id: pot.id,
          hand_id: hand_id,
          amount: pot.amount
        }
      )
    end)
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%PotsRecalculated{table_id: table_id, hand_id: hand_id, pots: pots}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}:pots",
      {:pots_updated, %{
        hand_id: hand_id,
        pots: Enum.map(pots, fn pot ->
          %{
            id: pot.id,
            amount: pot.amount,
            type: pot.type
          }
        end)
      }}
    )

    :ok
  end
end
