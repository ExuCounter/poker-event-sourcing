defmodule Poker.Wallet.PubSub do
  def subscribe_to_wallet(player_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "wallet:#{player_id}")
  end

  def broadcast_wallet(player_id, event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "wallet:#{player_id}",
      {:wallet, event, data |> Map.put(:player_id, player_id)}
    )

    :ok
  end
end
