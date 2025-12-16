defmodule Poker.Tables.Projectors.TablePotWinners do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.HandFinished
  alias Poker.Tables.Projections.TablePotWinners

  project(%HandFinished{hand_id: hand_id, payouts: payouts}, fn multi ->
    Enum.reduce(payouts, multi, fn payout, acc_multi ->
      winner_id = Ecto.UUID.generate()

      Ecto.Multi.insert(
        acc_multi,
        {:insert_winner, winner_id},
        %TablePotWinners{
          id: winner_id,
          hand_id: hand_id,
          pot_id: payout.pot_id,
          participant_id: payout.participant_id,
          amount: payout.amount
        }
      )
    end)
  end)

  @impl Commanded.Projections.Ecto
  def after_update(%HandFinished{table_id: table_id, hand_id: hand_id, payouts: payouts}, _metadata, _changes) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}:pot_winners",
      {:pot_winners_determined, %{
        hand_id: hand_id,
        winners: Enum.map(payouts, fn payout ->
          %{
            pot_id: payout.pot_id,
            participant_id: payout.participant_id,
            amount: payout.amount,
            hand_rank: payout.hand_rank
          }
        end)
      }}
    )

    :ok
  end
end
