defmodule Poker.Tables.Aggregates.Table.Apply.Pot do
  @moduledoc """
  Handles pot event application.
  """

  alias Poker.Tables.Aggregates.Table
  alias Poker.Tables.Events.PotsRecalculated

  def apply(%Table{} = table, %PotsRecalculated{pots: pots}) do
    %Table{table | pots: pots}
  end
end
