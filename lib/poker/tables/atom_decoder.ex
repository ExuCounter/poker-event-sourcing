defmodule Poker.Tables.AtomDecoder do
  @moduledoc """
  Whitelist-based atom conversion for Tables context event/snapshot deserialization.

  Instead of using `String.to_existing_atom/1` (which fails if atoms aren't loaded)
  or `String.to_atom/1` (which is unsafe), this module maintains explicit whitelists
  of allowed atoms per field specific to the Tables bounded context.

  ## Usage

      iex> AtomDecoder.decode(:status, "active")
      :active

      iex> AtomDecoder.decode(:status, "unknown_value")
      ** (ArgumentError) Invalid value "unknown_value" for field :status

      iex> AtomDecoder.decode(:status, :active)
      :active  # Already an atom, returned as-is
  """

  # Whitelist of allowed atoms per field
  @whitelists %{
    # Table status
    table_status: [
      :waiting,
      :live,
      :paused,
      :finished
    ],

    # Participant status
    participant_status: [
      :active,
      :folded,
      :busted,
      :playing,
      :waiting,
      :all_in
    ],

    # Table type
    table_type: [
      :six_max,
      :nine_max,
      :heads_up
    ],

    # Round types
    round_type: [
      :pre_flop,
      :flop,
      :turn,
      :river
    ],

    # Round completion reasons
    round_reason: [
      :all_folded,
      :all_acted
    ],

    # Hand finish reasons
    hand_finish_reason: [
      :showdown,
      :all_in_runout,
      :all_folded
    ],

    # Table pause reasons
    table_pause_reason: [
      :all_sitting_out
    ],

    # Table finish reasons
    table_finish_reason: [
      :completed
    ],

    # Card suits (full names)
    suit: [
      :hearts,
      :diamonds,
      :clubs,
      :spades
    ],

    # Card suits (short form used in hand_rank)
    suit_short: [
      :h,
      :d,
      :c,
      :s
    ],

    # Card ranks (face cards and ace as atoms)
    rank: [
      :A,
      :K,
      :Q,
      :J,
      :T
    ],

    # Player actions
    action: [
      :fold,
      :check,
      :call,
      :bet,
      :raise,
      :all_in
    ],

    # Pot types
    pot_type: [
      :main,
      :side,
      :combined
    ],

    # Player positions
    participant_position: [
      :dealer,
      :small_blind,
      :big_blind,
      :utg,
      :hijack,
      :cutoff
    ],

    # Hand ranking types (first element of hand rank tuple)
    hand_ranking: [
      :straight_flush,
      :four_of_a_kind,
      :full_house,
      :flush,
      :straight,
      :three_of_a_kind,
      :two_pair,
      :one_pair,
      :high_card
    ]
  }

  # Pre-compute string-to-atom map at compile time for O(1) lookup
  # This transforms @whitelists into a flat map like:
  # %{{:status, "active"} => :active, {:status, "waiting"} => :waiting, ...}
  @string_to_atom_map (
                        @whitelists
                        |> Enum.flat_map(fn {field, atoms} ->
                          Enum.map(atoms, fn atom ->
                            {{field, Atom.to_string(atom)}, atom}
                          end)
                        end)
                        |> Map.new()
                      )

  # Also create a set of valid atoms per field for validation
  @valid_atoms_by_field @whitelists
                        |> Enum.map(fn {field, atoms} -> {field, MapSet.new(atoms)} end)
                        |> Map.new()

  @doc """
  Decodes a string value to an atom using the whitelist for the given field.

  If the value is already an atom, validates it against the whitelist.
  Raises ArgumentError if the value is not in the whitelist.

  ## Examples

      iex> AtomDecoder.decode(:status, "active")
      :active

      iex> AtomDecoder.decode(:status, :active)
      :active

      iex> AtomDecoder.decode(:status, "invalid")
      ** (ArgumentError) Invalid value "invalid" for field :status
  """
  @spec decode(atom(), String.t() | atom() | list() | nil) :: atom() | tuple() | nil
  def decode(_field, nil), do: nil

  def decode(:hand_rank, value) when is_list(value), do: decode_hand_rank(value)
  def decode(:hand_rank, value) when is_tuple(value), do: value

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

  @doc """
  Returns the list of valid atoms for a given field.
  Useful for documentation and validation.
  """
  @spec valid_values(atom()) :: [atom()]
  def valid_values(field) do
    Map.fetch!(@whitelists, field)
  end

  @doc """
  Checks if a field is defined in the whitelist.
  """
  @spec field_defined?(atom()) :: boolean()
  def field_defined?(field) do
    Map.has_key?(@whitelists, field)
  end

  @doc """
  Decodes a hand rank from JSON list format to tuple.

  ## Examples

      iex> AtomDecoder.decode_hand_rank(["straight_flush", "A"])
      {:straight_flush, :A}

      iex> AtomDecoder.decode_hand_rank(["flush", "h", "A", "K", "J", 7, 5])
      {:flush, :h, :A, :K, :J, 7, 5}

      iex> AtomDecoder.decode_hand_rank(nil)
      nil
  """
  def decode_hand_rank(nil), do: nil

  def decode_hand_rank([type_str | rest]) do
    type = decode(:hand_ranking, type_str)

    components =
      case type do
        :flush ->
          [suit_str | ranks] = rest
          [decode(:suit_short, suit_str) | Enum.map(ranks, &decode_rank/1)]

        _ ->
          Enum.map(rest, &decode_rank/1)
      end

    List.to_tuple([type | components])
  end

  defp decode_rank(int) when is_integer(int), do: int
  defp decode_rank(str) when is_binary(str), do: decode(:rank, str)

  @doc """
  Decodes a card from JSON map format to domain format.

  ## Examples

      iex> AtomDecoder.decode_card(%{"rank" => "A", "suit" => "spades"})
      %{rank: :A, suit: :spades}

      iex> AtomDecoder.decode_card(%{rank: "K", suit: "hearts"})
      %{rank: :K, suit: :hearts}

      iex> AtomDecoder.decode_card(%{rank: 7, suit: "diamonds"})
      %{rank: 7, suit: :diamonds}

      iex> AtomDecoder.decode_card(%{rank: :A, suit: :spades})
      %{rank: :A, suit: :spades}
  """
  def decode_card(nil), do: nil

  def decode_card(%{rank: rank, suit: suit}) when is_atom(rank) and is_atom(suit) do
    # Already decoded
    %{rank: rank, suit: suit}
  end

  def decode_card(%{rank: rank, suit: suit}) do
    %{
      rank: decode_card_rank(rank),
      suit: decode(:suit, suit)
    }
  end

  def decode_card(%{"rank" => rank, "suit" => suit}) do
    %{
      rank: decode_card_rank(rank),
      suit: decode(:suit, suit)
    }
  end

  @doc """
  Decodes a list of cards from JSON format to domain format.

  ## Examples

      iex> AtomDecoder.decode_cards([%{"rank" => "A", "suit" => "spades"}, %{"rank" => "K", "suit" => "hearts"}])
      [%{rank: :A, suit: :spades}, %{rank: :K, suit: :hearts}]
  """
  def decode_cards(nil), do: nil
  def decode_cards(cards) when is_list(cards), do: Enum.map(cards, &decode_card/1)

  defp decode_card_rank(rank) when is_integer(rank), do: rank
  defp decode_card_rank(rank) when is_atom(rank), do: rank
  defp decode_card_rank(rank) when is_binary(rank), do: decode(:rank, rank)

  @doc """
  Decodes a DateTime from ISO8601 string format.

  ## Examples

      iex> AtomDecoder.decode_datetime("2024-01-15T10:30:00Z")
      ~U[2024-01-15 10:30:00Z]

      iex> AtomDecoder.decode_datetime(~U[2024-01-15 10:30:00Z])
      ~U[2024-01-15 10:30:00Z]
  """
  def decode_datetime(nil), do: nil
  def decode_datetime(%DateTime{} = dt), do: dt

  def decode_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> str
    end
  end

  @doc """
  Decodes a pot from JSON format to domain format.

  ## Examples

      iex> AtomDecoder.decode_pot(%{type: "main", amount: 100})
      %{type: :main, amount: 100}

      iex> AtomDecoder.decode_pot(%{type: :main, amount: 100})
      %{type: :main, amount: 100}
  """
  def decode_pot(nil), do: nil

  def decode_pot(%{type: type} = pot) when is_atom(type) do
    pot
  end

  def decode_pot(%{type: type} = pot) when is_binary(type) do
    %{pot | type: decode(:pot_type, type)}
  end

  @doc """
  Decodes a list of pots from JSON format to domain format.
  """
  def decode_pots(nil), do: nil
  def decode_pots(pots) when is_list(pots), do: Enum.map(pots, &decode_pot/1)
end
