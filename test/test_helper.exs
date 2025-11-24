Mox.defmock(Poker.Services.DeckMock, for: Poker.Services.Deck.Behaviour)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Poker.Repo, :manual)
