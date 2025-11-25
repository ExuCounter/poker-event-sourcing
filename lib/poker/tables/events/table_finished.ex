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
  def decode(%Poker.Tables.Events.TableFinished{} = event) do
    %Poker.Tables.Events.TableFinished{
      event
      | reason: String.to_existing_atom(event.reason)
    }
  end
end
