defmodule Poker.Tables.Aggregates.Table.Apply.Pot do
  @moduledoc """
  Applies pot-related events to aggregate state.

  Handles the following events:
  - `PotsRecalculated` - Updates pot structure after betting actions

  Pots are recalculated after each betting round to handle side pots
  created when players go all-in with different stack sizes.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.PotsRecalculated

  @doc "Updates the pot structure with recalculated pots."
  def apply(%Table{} = table, %PotsRecalculated{pots: pots}) do
    %Table{table | pots: pots}
  end
end
