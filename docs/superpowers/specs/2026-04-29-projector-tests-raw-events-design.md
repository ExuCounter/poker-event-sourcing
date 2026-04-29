# Projector Tests: Raw Events Instead of SeedFactory

## Problem

Current projector tests (`TableListTest`, `TableLobbyTest`) use SeedFactory to dispatch commands through the full pipeline (commands → aggregates → events → projectors). This means:

- Tests are slow (full pipeline for each scenario)
- Tests are brittle (coupled to aggregate/tournament/cash game logic, deck fixtures)
- Tests are noisy (intermediate events fire that the projector test doesn't care about)

## Approach

Call projector `handle/2` functions directly with hand-constructed event structs. The `project` macro in `Commanded.Projections.Ecto` generates `handle/2` clauses that:

1. Run the `Ecto.Multi` (insert/update the projection)
2. Fire `after_update` callbacks (PubSub broadcasts)

No commands, aggregates, event store, deck fixtures, or SeedFactory involved.

## Test Pattern

Each test follows:

1. Construct event structs with minimal required fields
2. Call `ProjectorModule.handle(event, metadata)` — runs Multi + after_update
3. Assert projection state via `Repo.get`
4. Assert PubSub messages via `assert_receive`

For tests needing prior state, chain `handle/2` calls:

```elixir
test "seated count decreases when participant busted" do
  table_id = Ecto.UUID.generate()

  :ok = TableList.handle(%TableCreated{id: table_id, status: :waiting, table_type: :six_max, ...}, %{})
  :ok = TableList.handle(%ParticipantJoined{table_id: table_id, ...}, %{})
  :ok = TableList.handle(%ParticipantBusted{table_id: table_id, ...}, %{})

  table = Repo.get(TableList, table_id)
  assert table.seated_count == 0
end
```

## Projectors to Update

### TableList (`test/poker/tables/projectors/table_list_test.exs`)

Events used by projector:
- `TableCreated` — insert new row
- `TableStarted` — update status to `:live`
- `ParticipantJoined` — increment `seated_count`
- `ParticipantBusted` — decrement `seated_count`
- `TableFinished` — update status to `:finished`
- `TablePaused` — update status to `:paused`
- `TableResumed` — update status to `:live`

No external dependencies. All tests can use raw events directly.

### TableLobby (`test/poker/tables/projectors/table_lobby_test.exs`)

Events used by projector:
- `TableCreated` — insert new row with blinds, stack, type
- `TableStarted` — update status
- `ParticipantJoined` — add participant to embedded list, increment count
- `ParticipantBusted` — mark participant as busted, decrement count
- `ParticipantLeft` — remove participant from list, decrement count
- `TableFinished` — update status
- `TablePaused` / `TableResumed` — update status

**User dependency:** `ParticipantJoined` handler calls `Poker.Accounts.get_user!(player_id)` to fetch email/nickname. Tests that involve `ParticipantJoined` must create a real user via `Poker.Accounts.register_user/1`.

## What Gets Removed

- `use SeedFactory.Test` no longer needed in projector test modules
- `import Poker.DeckFixtures` / `arrange_deck` removed entirely
- `exec(:create_tournament)`, `exec(:fill_tournament)`, `exec(:start_runout)` replaced with direct `handle/2` calls
- No more PubSub noise from intermediate events

## What Stays

- `use Poker.DataCase` — still needed for Repo/sandbox
- PubSub subscribe + `assert_receive` — still tested inline
- `Poker.Accounts.register_user/1` — used directly (not via SeedFactory) where TableLobby needs user data
