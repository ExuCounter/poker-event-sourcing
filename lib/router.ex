defmodule Poker.Router do
  use Commanded.Commands.Router
  alias Poker.Accounts.Commands.{RegisterPlayer}
  alias Poker.Accounts.Aggregates.{Player}

  identify(Player, by: :player_uuid)

  dispatch(
    [
      RegisterPlayer
    ],
    to: Player
  )
end
