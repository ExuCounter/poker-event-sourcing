defmodule Poker.Tables.Events.TablePaused do
  @derive {Jason.Encoder, only: [:table_id, :reason]}
  defstruct [:table_id, :reason]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.TablePaused do
  def decode(%Poker.Tables.Events.TablePaused{reason: reason} = event) do
    %Poker.Tables.Events.TablePaused{event | reason: String.to_atom(reason)}
  end
end
