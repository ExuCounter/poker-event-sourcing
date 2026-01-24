defmodule PokerWeb.JsonEncoder do
  @moduledoc """
  Custom JSON encoder that transforms map keys to camelCase.
  Used for LiveView events to provide consistent camelCase format to JavaScript frontend.
  """

  @doc """
  Recursively transforms all map keys from snake_case to camelCase.
  Handles nested maps and lists of maps.
  """

  def transform_keys(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  def transform_keys(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  def transform_keys(map) when is_struct(map) do
    map
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
    |> Enum.map(fn {k, v} -> {to_camel_case(k), transform_keys(v)} end)
    |> Enum.into(%{})
  end

  def transform_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {to_camel_case(k), transform_keys(v)} end)
    |> Enum.into(%{})
  end

  def transform_keys(list) when is_list(list) do
    Enum.map(list, &transform_keys/1)
  end

  def transform_keys(value), do: value

  defp to_camel_case(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> to_camel_case()
  end

  defp to_camel_case(string) when is_binary(string) do
    string
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map(fn
      {part, 0} -> part
      {part, _} -> String.capitalize(part)
    end)
    |> Enum.join()
  end

  defp to_camel_case(other), do: other
end
