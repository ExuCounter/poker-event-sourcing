defmodule Poker.Queries do
  import Ecto.Query

  def filter_with(query, expr) do
    Enum.reduce(expr, query, fn
      {field, value}, query when is_list(value) ->
        where(query, [data], field(data, ^field) in ^value)

      {field, value}, query ->
        where(query, [data], field(data, ^field) == ^value)
    end)
  end
end
