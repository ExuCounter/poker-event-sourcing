defmodule Poker.Tables.Events.TableFinished do
  @derive {Jason.Encoder,
           only: [
             :table_id,
             :reason
           ]}
  defstruct [
    :table_id,
    :reason
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.TableFinished do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.TableFinished{reason: reason} = event) do
    %Poker.Tables.Events.TableFinished{
      event
      | reason: AtomDecoder.decode(:table_finish_reason, reason)
    }
  end
end
