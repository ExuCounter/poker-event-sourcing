defmodule Poker.Tournaments.AtomDecoder do
  @whitelists %{
    tournament_status: [
      :registering,
      :active,
      :finished
    ],
    speed: [
      :regular,
      :turbo,
      :hyper_turbo
    ],
    table_type: [
      :two_max,
      :three_max,
      :four_max,
      :six_max
    ]
  }

  @string_to_atom_map (
                        @whitelists
                        |> Enum.flat_map(fn {field, atoms} ->
                          Enum.map(atoms, fn atom ->
                            {{field, Atom.to_string(atom)}, atom}
                          end)
                        end)
                        |> Map.new()
                      )

  @valid_atoms_by_field @whitelists
                        |> Enum.map(fn {field, atoms} -> {field, MapSet.new(atoms)} end)
                        |> Map.new()

  @spec decode(atom(), String.t() | atom() | nil) :: atom() | nil
  def decode(_field, nil), do: nil

  def decode(field, value) when is_atom(value) do
    valid_set = Map.fetch!(@valid_atoms_by_field, field)

    if MapSet.member?(valid_set, value) do
      value
    else
      raise ArgumentError,
            "Invalid atom #{inspect(value)} for field #{inspect(field)}. " <>
              "Allowed values: #{inspect(MapSet.to_list(valid_set))}"
    end
  end

  def decode(field, value) when is_binary(value) do
    case Map.fetch(@string_to_atom_map, {field, value}) do
      {:ok, atom} ->
        atom

      :error ->
        valid_set = Map.get(@valid_atoms_by_field, field, MapSet.new())

        raise ArgumentError,
              "Invalid value #{inspect(value)} for field #{inspect(field)}. " <>
                "Allowed values: #{inspect(MapSet.to_list(valid_set))}"
    end
  end
end
