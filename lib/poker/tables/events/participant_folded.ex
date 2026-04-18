defmodule Poker.Tables.Events.ParticipantFolded do
  @derive {Jason.Encoder,
           only: [
             :id,
             :participant_id,
             :table_hand_id,
             :table_id,
             :status,
             :round,
             :folded_at
           ]}
  defstruct [
    :id,
    :participant_id,
    :table_hand_id,
    :table_id,
    :status,
    :round,
    :folded_at
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantFolded do
  def decode(%Poker.Tables.Events.ParticipantFolded{} = event) do
    {:ok, folded_at, _offset} = DateTime.from_iso8601(event.folded_at)

    status =
      case event.status do
        status when is_atom(status) -> status
        status when is_binary(status) -> String.to_existing_atom(status)
      end

    %Poker.Tables.Events.ParticipantFolded{event | folded_at: folded_at, status: status}
  end
end
