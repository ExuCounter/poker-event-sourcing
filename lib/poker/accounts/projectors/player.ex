defmodule Poker.Accounts.Projectors.Player do
  use Commanded.Projections.Ecto,
    name: "Accounts.Projectors.Player",
    repo: Poker.Repo,
    application: Poker.App,
    consistency: :strong

  project(%Poker.Accounts.Events.PlayerRegistered{} = registered, fn multi ->
    Ecto.Multi.insert(multi, :player, %Poker.Accounts.Projections.Player{
      id: registered.id,
      email: registered.email
    })
  end)
end
