defmodule Poker.Ecto.Card do
  use Ecto.Type

  def type, do: :map

  def cast(%{rank: rank, suit: suit} = card) when is_binary(rank) and is_binary(suit) do
    {:ok, card}
  end

  def cast(%{"rank" => rank, "suit" => suit}) when is_binary(rank) and is_binary(suit) do
    {:ok, %{rank: rank, suit: suit}}
  end

  def cast(_), do: :error

  def load(data) when is_map(data) do
    {:ok,
     %{
       rank: data["rank"],
       suit: data["suit"]
     }}
  end

  def dump(%{rank: rank, suit: suit}) when is_binary(rank) and is_binary(suit) do
    {:ok, %{"rank" => rank, "suit" => suit}}
  end

  def dump(_), do: :error
end
