defmodule Poker.Tables.Events.TableStarted do
  @derive {Jason.Encoder, only: [:id, :status]}
  defstruct [:id, :status]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.TableStarted do
  def decode(%Poker.Tables.Events.TableStarted{status: status} = event) do
    %Poker.Tables.Events.TableStarted{event | status: status |> String.to_existing_atom()}
  end
end
