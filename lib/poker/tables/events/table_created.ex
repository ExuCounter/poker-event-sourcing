defmodule Poker.Tables.Events.TableCreated do
  @derive {Jason.Encoder,
           only: [
             :id,
             :creator_id,
             :status,
             :small_blind,
             :big_blind,
             :starting_stack,
             :timeout_seconds,
             :table_type,
             :game_mode,
             :source_id
           ]}
  defstruct [
    :id,
    :creator_id,
    :status,
    :small_blind,
    :big_blind,
    :starting_stack,
    :timeout_seconds,
    :table_type,
    :game_mode,
    :source_id
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.TableCreated do
  alias Poker.Tables.AtomDecoder

  def decode(
        %Poker.Tables.Events.TableCreated{
          status: status,
          table_type: table_type,
          game_mode: game_mode
        } = event
      ) do
    %Poker.Tables.Events.TableCreated{
      event
      | status: AtomDecoder.decode(:table_status, status),
        table_type: AtomDecoder.decode(:table_type, table_type),
        game_mode: AtomDecoder.decode(:game_mode, game_mode)
    }
  end
end
