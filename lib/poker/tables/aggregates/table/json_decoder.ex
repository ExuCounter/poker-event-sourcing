defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Aggregates.Table do
  @moduledoc """
  Decodes Table aggregate from JSON for Commanded snapshots.

  Converts string representations of atoms back to atoms for:
  - Top-level status
  - Settings (table_type)
  - Participants (status)
  - Participant hands (position, status)
  - Round (type)
  - Pots (type)
  """

  alias Poker.Tables.Aggregates.Table

  def decode(%Table{} = table) do
    table
    |> decode_status()
    |> decode_settings()
    |> decode_participants()
    |> decode_participant_hands()
    |> decode_round()
    |> decode_pots()
  end

  # Top-level status conversion
  defp decode_status(%Table{status: nil} = table), do: table

  defp decode_status(%Table{status: status} = table) when is_binary(status) do
    %{table | status: String.to_existing_atom(status)}
  end

  defp decode_status(table), do: table

  # Settings: table_type conversion
  defp decode_settings(%Table{settings: nil} = table), do: table

  defp decode_settings(%Table{settings: settings} = table) when is_map(settings) do
    updated_settings = decode_settings_map(settings)
    %{table | settings: updated_settings}
  end

  defp decode_settings(table), do: table

  defp decode_settings_map(%{"table_type" => table_type} = settings)
       when is_binary(table_type) do
    %{settings | "table_type" => String.to_existing_atom(table_type)}
  end

  defp decode_settings_map(settings), do: settings

  # Participants: status conversion for each participant
  defp decode_participants(%Table{participants: nil} = table), do: table

  defp decode_participants(%Table{participants: participants} = table)
       when is_list(participants) do
    updated_participants = Enum.map(participants, &decode_participant/1)
    %{table | participants: updated_participants}
  end

  defp decode_participants(table), do: table

  defp decode_participant(%{status: status} = participant) when is_binary(status) do
    %{participant | status: String.to_existing_atom(status)}
  end

  defp decode_participant(participant), do: participant

  # Participant hands: position and status conversion
  defp decode_participant_hands(%Table{participant_hands: nil} = table), do: table

  defp decode_participant_hands(%Table{participant_hands: hands} = table)
       when is_list(hands) do
    updated_hands = Enum.map(hands, &decode_participant_hand/1)
    %{table | participant_hands: updated_hands}
  end

  defp decode_participant_hands(table), do: table

  defp decode_participant_hand(hand) do
    hand
    |> decode_hand_position()
    |> decode_hand_status()
  end

  defp decode_hand_position(%{position: position} = hand) when is_binary(position) do
    %{hand | position: String.to_existing_atom(position)}
  end

  defp decode_hand_position(hand), do: hand

  defp decode_hand_status(%{status: status} = hand) when is_binary(status) do
    %{hand | status: String.to_existing_atom(status)}
  end

  defp decode_hand_status(hand), do: hand

  # Round: type conversion
  defp decode_round(%Table{round: nil} = table), do: table

  defp decode_round(%Table{round: %{type: type} = round} = table) when is_binary(type) do
    updated_round = %{round | type: String.to_existing_atom(type)}
    %{table | round: updated_round}
  end

  defp decode_round(table), do: table

  # Pots: type conversion for each pot
  defp decode_pots(%Table{pots: nil} = table), do: table

  defp decode_pots(%Table{pots: pots} = table) when is_list(pots) do
    updated_pots = Enum.map(pots, &decode_pot/1)
    %{table | pots: updated_pots}
  end

  defp decode_pots(table), do: table

  defp decode_pot(%{type: type} = pot) when is_binary(type) do
    %{pot | type: String.to_existing_atom(type)}
  end

  defp decode_pot(pot), do: pot
end
