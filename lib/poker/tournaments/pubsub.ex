defmodule Poker.Tournaments.PubSub do
  def subscribe_to_tournament(tournament_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "tournament:#{tournament_id}")
  end

  def subscribe_to_tournament_list do
    Phoenix.PubSub.subscribe(Poker.PubSub, "tournament_list")
  end

  def broadcast_tournament(tournament_id, event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "tournament:#{tournament_id}",
      {:tournament, event, data |> Map.put(:tournament_id, tournament_id)}
    )

    :ok
  end

  def broadcast_tournament_list(event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "tournament_list",
      {:tournament_list, event, data}
    )

    :ok
  end
end
