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
             :table_type
           ]}
  defstruct [
    :id,
    :creator_id,
    :status,
    :small_blind,
    :big_blind,
    :starting_stack,
    :timeout_seconds,
    :table_type
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.TableCreated do
  def decode(%Poker.Tables.Events.TableCreated{status: status, table_type: table_type} = event) do
    %Poker.Tables.Events.TableCreated{
      event
      | status: status |> String.to_existing_atom(),
        table_type: table_type |> String.to_existing_atom()
    }
  end
end
