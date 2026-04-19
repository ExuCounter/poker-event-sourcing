defmodule Poker.Tables.Events.TableStarted do
  @derive {Jason.Encoder, only: [:id, :status]}
  defstruct [:id, :status]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.TableStarted do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.TableStarted{status: status} = event) do
    %Poker.Tables.Events.TableStarted{
      event
      | status: AtomDecoder.decode(:table_status, status)
    }
  end
end
