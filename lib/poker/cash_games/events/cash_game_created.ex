defmodule Poker.CashGames.Events.CashGameCreated do
  @derive {Jason.Encoder,
           only: [
             :cash_game_id,
             :table_id,
             :creator_id,
             :code,
             :status,
             :small_blind,
             :big_blind,
             :min_buyin,
             :max_buyin,
             :table_type
           ]}
  defstruct [
    :cash_game_id,
    :table_id,
    :creator_id,
    :code,
    :status,
    :small_blind,
    :big_blind,
    :min_buyin,
    :max_buyin,
    :table_type
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.CashGames.Events.CashGameCreated do
  alias Poker.CashGames.AtomDecoder

  def decode(
        %Poker.CashGames.Events.CashGameCreated{status: status, table_type: table_type} = event
      ) do
    %Poker.CashGames.Events.CashGameCreated{
      event
      | status: AtomDecoder.decode(:cash_game_status, status),
        table_type: AtomDecoder.decode(:table_type, table_type)
    }
  end
end
