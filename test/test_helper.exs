Mox.defmock(Poker.Services.DeckMock, for: Poker.Services.Deck.Behaviour)
Mox.defmock(Poker.Services.HandEvaluatorMock, for: Poker.Services.HandEvaluator.Behaviour)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Poker.Repo, :manual)
