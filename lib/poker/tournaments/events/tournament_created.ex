defmodule Poker.Tournaments.Events.TournamentCreated do
  @derive {Jason.Encoder,
           only: [
             :id,
             :creator_id,
             :code,
             :status,
             :speed,
             :buy_in,
             :starting_stack,
             :table_type,
             :max_players
           ]}
  defstruct [
    :id,
    :creator_id,
    :code,
    :status,
    :speed,
    :buy_in,
    :starting_stack,
    :table_type,
    :max_players
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tournaments.Events.TournamentCreated do
  alias Poker.Tournaments.AtomDecoder

  def decode(%Poker.Tournaments.Events.TournamentCreated{} = event) do
    %Poker.Tournaments.Events.TournamentCreated{
      event
      | status: AtomDecoder.decode(:tournament_status, event.status),
        speed: AtomDecoder.decode(:speed, event.speed),
        table_type: AtomDecoder.decode(:table_type, event.table_type)
    }
  end
end
