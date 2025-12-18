defmodule Poker.TableEvents do
  def subscribe_to_table(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}")
  end

  def subscribe_to_lobby(table_id) do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:lobby")
  end

  def subscribe_to_table_list() do
    Phoenix.PubSub.subscribe(Poker.PubSub, "table_list")
  end

  def unsubscribe_from_table(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}")
  end

  def unsubscribe_from_lobby(table_id) do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table:#{table_id}:lobby")
  end

  def unsubscribe_from_table_list() do
    Phoenix.PubSub.unsubscribe(Poker.PubSub, "table_list")
  end

  def broadcast_table(table_id, event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}",
      {:table, event, data |> Map.put(:table_id, table_id)}
    )

    :ok
  end

  def broadcast_lobby(table_id, event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table:#{table_id}:lobby",
      {:table_lobby, event, data |> Map.put(:table_id, table_id)}
    )

    :ok
  end

  def broadcast_table_list(table_id, event, data \\ %{}) do
    Phoenix.PubSub.broadcast(
      Poker.PubSub,
      "table_list",
      {:table_list, event, data |> Map.put(:table_id, table_id)}
    )

    :ok
  end
end
