# Broadcastable Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the catch-all `TableEventBroadcaster` with a `Broadcastable` protocol so each event explicitly declares whether it should be broadcast and what data is safe to send.

**Architecture:** Define a `Poker.Tables.Events.Broadcastable` protocol with a single function `for_broadcast/1` that returns either `{:broadcast, sanitized_map}` or `:skip`. Each event implements the protocol. The `TableEventBroadcaster` calls the protocol instead of blindly broadcasting everything. Events without an implementation don't compile if broadcast is attempted (protocol not implemented error = safe default).

**Tech Stack:** Elixir protocols, Commanded event handlers, Phoenix PubSub

---

## Event Classification

Based on analysis of all 33 events:

**Skip (internal/sensitive — never broadcast to game LiveView):**
- `DeckGenerated` — full deck order (secret)
- `DeckUpdated` — remaining deck (secret)
- `RoundCompleted` — internal bookkeeping, no animation
- `TableCreated` — handled by lobby/list projectors
- `TableStarted` — handled by lobby/list projectors
- `TableFinished` — handled by lobby/list projectors
- `TablePaused` — handled by lobby/list projectors
- `TableResumed` — handled by lobby/list projectors
- `ParticipantJoined` — handled by lobby/list projectors
- `ParticipantLeft` — handled by lobby/list projectors
- `ParticipantBusted` — handled by lobby/list projectors
- `TableBlindsUpdated` — internal, no game animation
- `ParticipantBoughtIn` — internal, no game animation
- `ParticipantBuyInApplied` — internal, no game animation

**Broadcast (sanitized — strip sensitive fields):**
- `ParticipantHandGiven` — broadcast but **strip `hole_cards`** (the game view handles per-player card visibility)

**Broadcast (as-is — all fields are public):**
- `HandStarted`
- `HandFinished`
- `SmallBlindPosted`
- `BigBlindPosted`
- `ParticipantFolded`
- `ParticipantCalled`
- `ParticipantChecked`
- `ParticipantRaised`
- `ParticipantWentAllIn`
- `ParticipantTimedOut`
- `ParticipantSatOut`
- `ParticipantSatIn`
- `ParticipantToActSelected`
- `RoundStarted` (community cards are public)
- `PotsRecalculated`
- `PayoutDistributed`
- `ParticipantShowdownCardsRevealed` (showdown cards are public)
- `DealerButtonMoved`

---

### Task 1: Define the Broadcastable protocol

**Files:**
- Create: `lib/poker/tables/events/broadcastable.ex`
- Test: `test/poker/tables/events/broadcastable_test.exs`

- [ ] **Step 1: Write the test for the protocol**

```elixir
defmodule Poker.Tables.Events.BroadcastableTest do
  use ExUnit.Case, async: true

  alias Poker.Tables.Events.Broadcastable

  describe "for_broadcast/1" do
    test "public events return {:broadcast, map}" do
      event = %Poker.Tables.Events.HandStarted{id: "h1", table_id: "t1"}
      assert {:broadcast, data} = Broadcastable.for_broadcast(event)
      assert data.table_id == "t1"
    end

    test "sensitive events return :skip" do
      event = %Poker.Tables.Events.DeckGenerated{hand_id: "h1", table_id: "t1", cards: ["As", "Kh"]}
      assert :skip = Broadcastable.for_broadcast(event)
    end

    test "ParticipantHandGiven strips hole_cards" do
      event = %Poker.Tables.Events.ParticipantHandGiven{
        id: "p1",
        table_id: "t1",
        participant_id: "part1",
        hand_id: "h1",
        hole_cards: [{:ace, :spades}, {:king, :hearts}],
        position: :dealer,
        status: :active,
        bet_this_round: 0,
        total_bet_this_hand: 0
      }

      assert {:broadcast, data} = Broadcastable.for_broadcast(event)
      refute Map.has_key?(data, :hole_cards)
      assert data.participant_id == "part1"
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/poker/tables/events/broadcastable_test.exs`
Expected: FAIL — protocol not defined

- [ ] **Step 3: Define the protocol**

```elixir
defprotocol Poker.Tables.Events.Broadcastable do
  @moduledoc """
  Protocol for events that should be broadcast to game LiveViews via PubSub.

  Returns `{:broadcast, sanitized_map}` for events that should be sent,
  or `:skip` for events that should not be broadcast (internal/sensitive).

  Events without an implementation will raise Protocol.UndefinedError,
  which the broadcaster catches and skips — making "no broadcast" the safe default.
  """

  @doc """
  Returns `{:broadcast, map}` with sanitized data, or `:skip`.
  """
  @fallback_to_any true
  def for_broadcast(event)
end

defimpl Poker.Tables.Events.Broadcastable, for: Any do
  def for_broadcast(_event), do: :skip
end
```

- [ ] **Step 4: Run the test to verify it still fails**

Run: `mix test test/poker/tables/events/broadcastable_test.exs`
Expected: FAIL — HandStarted returns `:skip` (fallback to Any), but test expects `{:broadcast, _}`

- [ ] **Step 5: Commit protocol definition**

```bash
git add lib/poker/tables/events/broadcastable.ex test/poker/tables/events/broadcastable_test.exs
git commit -m "feat: define Broadcastable protocol with fallback :skip"
```

---

### Task 2: Implement Broadcastable for all broadcast events

**Files:**
- Modify: `lib/poker/tables/events/broadcastable.ex` (add all implementations)

- [ ] **Step 1: Add broadcast-as-is implementations**

Add to `lib/poker/tables/events/broadcastable.ex`, after the `Any` fallback:

```elixir
# -- Broadcast as-is (all fields are public) --

for event_module <- [
      Poker.Tables.Events.HandStarted,
      Poker.Tables.Events.HandFinished,
      Poker.Tables.Events.SmallBlindPosted,
      Poker.Tables.Events.BigBlindPosted,
      Poker.Tables.Events.ParticipantFolded,
      Poker.Tables.Events.ParticipantCalled,
      Poker.Tables.Events.ParticipantChecked,
      Poker.Tables.Events.ParticipantRaised,
      Poker.Tables.Events.ParticipantWentAllIn,
      Poker.Tables.Events.ParticipantTimedOut,
      Poker.Tables.Events.ParticipantSatOut,
      Poker.Tables.Events.ParticipantSatIn,
      Poker.Tables.Events.ParticipantToActSelected,
      Poker.Tables.Events.RoundStarted,
      Poker.Tables.Events.PotsRecalculated,
      Poker.Tables.Events.PayoutDistributed,
      Poker.Tables.Events.ParticipantShowdownCardsRevealed,
      Poker.Tables.Events.DealerButtonMoved
    ] do
  defimpl Poker.Tables.Events.Broadcastable, for: event_module do
    def for_broadcast(event), do: {:broadcast, Map.from_struct(event)}
  end
end
```

- [ ] **Step 2: Add sanitized implementation for ParticipantHandGiven**

```elixir
defimpl Poker.Tables.Events.Broadcastable, for: Poker.Tables.Events.ParticipantHandGiven do
  def for_broadcast(event) do
    sanitized =
      event
      |> Map.from_struct()
      |> Map.delete(:hole_cards)

    {:broadcast, sanitized}
  end
end
```

- [ ] **Step 3: Run the tests**

Run: `mix test test/poker/tables/events/broadcastable_test.exs`
Expected: All 3 tests PASS

- [ ] **Step 4: Add more test coverage for edge cases**

Add to the test file:

```elixir
test "all skipped events return :skip" do
  skipped_events = [
    %Poker.Tables.Events.DeckGenerated{hand_id: "h1", table_id: "t1", cards: []},
    %Poker.Tables.Events.DeckUpdated{hand_id: "h1", table_id: "t1", cards: []},
    %Poker.Tables.Events.RoundCompleted{id: "r1", hand_id: "h1", table_id: "t1", type: :flop, reason: :completed},
    %Poker.Tables.Events.TableCreated{id: "t1", creator_id: "c1", status: :waiting, small_blind: 10, big_blind: 20, starting_stack: 1000, timeout_seconds: 30, table_type: :six_max, game_mode: :cash_game, source_id: nil},
    %Poker.Tables.Events.TableStarted{id: "t1", status: :live},
    %Poker.Tables.Events.TableFinished{table_id: "t1", reason: :completed},
    %Poker.Tables.Events.TablePaused{table_id: "t1", reason: :blind_level},
    %Poker.Tables.Events.TableResumed{table_id: "t1"},
    %Poker.Tables.Events.ParticipantJoined{id: "p1", player_id: "pl1", table_id: "t1", chips: 1000, initial_chips: 1000, status: :active, is_sitting_out: false, nickname: "test", seat_number: 1},
    %Poker.Tables.Events.ParticipantLeft{table_id: "t1", participant_id: "p1", player_id: "pl1", chips: 1000},
    %Poker.Tables.Events.ParticipantBusted{table_id: "t1", hand_id: "h1", participant_id: "p1", player_id: "pl1"},
    %Poker.Tables.Events.TableBlindsUpdated{table_id: "t1", small_blind: 20, big_blind: 40},
    %Poker.Tables.Events.ParticipantBoughtIn{participant_id: "p1", player_id: "pl1", table_id: "t1", amount: 1000},
    %Poker.Tables.Events.ParticipantBuyInApplied{participant_id: "p1", table_id: "t1", amount: 1000}
  ]

  for event <- skipped_events do
    assert :skip = Broadcastable.for_broadcast(event),
           "Expected :skip for #{inspect(event.__struct__)}"
  end
end

test "all broadcast events return {:broadcast, map}" do
  broadcast_events = [
    %Poker.Tables.Events.HandStarted{id: "h1", table_id: "t1"},
    %Poker.Tables.Events.HandFinished{table_id: "t1", hand_id: "h1", finish_reason: :showdown},
    %Poker.Tables.Events.SmallBlindPosted{id: "sb1", table_id: "t1", hand_id: "h1", participant_id: "p1", amount: 10},
    %Poker.Tables.Events.BigBlindPosted{id: "bb1", table_id: "t1", hand_id: "h1", participant_id: "p2", amount: 20},
    %Poker.Tables.Events.ParticipantFolded{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :folded, round: :preflop, folded_at: :preflop},
    %Poker.Tables.Events.ParticipantCalled{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :called, amount: 20, round: :preflop},
    %Poker.Tables.Events.ParticipantChecked{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :checked, round: :flop},
    %Poker.Tables.Events.ParticipantRaised{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :raised, amount: 40, round: :preflop},
    %Poker.Tables.Events.ParticipantWentAllIn{participant_id: "p1", hand_id: "h1", table_id: "t1", status: :all_in, amount: 1000, round: :preflop},
    %Poker.Tables.Events.ParticipantTimedOut{id: "to1", table_id: "t1", participant_id: "p1", round_id: "r1"},
    %Poker.Tables.Events.ParticipantSatOut{participant_id: "p1", table_id: "t1"},
    %Poker.Tables.Events.ParticipantSatIn{participant_id: "p1", table_id: "t1"},
    %Poker.Tables.Events.ParticipantToActSelected{table_id: "t1", round_id: "r1", participant_id: "p1", timeout_seconds: 30, started_at: nil},
    %Poker.Tables.Events.RoundStarted{id: "r1", hand_id: "h1", table_id: "t1", type: :flop, community_cards: []},
    %Poker.Tables.Events.PotsRecalculated{id: "pot1", table_id: "t1", hand_id: "h1", pots: []},
    %Poker.Tables.Events.PayoutDistributed{table_id: "t1", hand_id: "h1", pot_id: "pot1", participant_id: "p1", amount: 100, pot_type: :main, hand_rank: nil},
    %Poker.Tables.Events.ParticipantShowdownCardsRevealed{table_id: "t1", hand_id: "h1", participant_id: "p1", hole_cards: []},
    %Poker.Tables.Events.DealerButtonMoved{table_id: "t1", hand_id: "h1", participant_id: "p1"}
  ]

  for event <- broadcast_events do
    assert {:broadcast, data} = Broadcastable.for_broadcast(event),
           "Expected {:broadcast, _} for #{inspect(event.__struct__)}"
    assert is_map(data)
  end
end
```

- [ ] **Step 5: Run all tests**

Run: `mix test test/poker/tables/events/broadcastable_test.exs`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add lib/poker/tables/events/broadcastable.ex test/poker/tables/events/broadcastable_test.exs
git commit -m "feat: implement Broadcastable protocol for all table events"
```

---

### Task 3: Update TableEventBroadcaster to use the protocol

**Files:**
- Modify: `lib/poker/tables/event_handlers/table_event_broadcaster.ex`

- [ ] **Step 1: Update the broadcaster to use the protocol**

Replace the contents of `lib/poker/tables/event_handlers/table_event_broadcaster.ex`:

```elixir
defmodule Poker.Tables.EventHandlers.TableEventBroadcaster do
  @moduledoc """
  Event handler that broadcasts table events to connected clients via PubSub.

  Uses the Broadcastable protocol to determine which events should be broadcast
  and to sanitize sensitive data before sending.
  """

  use Commanded.Event.Handler,
    application: Poker.App,
    name: __MODULE__,
    consistency: :strong

  alias Poker.Tables.Events.Broadcastable
  alias Poker.Tables.EventTransformer

  def handle(event, metadata)
      when is_struct(event) and is_map_key(event, :table_id) and
             is_map_key(metadata, :event_id) and is_map_key(metadata, :stream_version) do
    case Broadcastable.for_broadcast(event) do
      {:broadcast, _sanitized_data} ->
        transformed_event = EventTransformer.transform(event, metadata)

        Poker.Tables.PubSub.broadcast_table(
          event.table_id,
          transformed_event.type,
          transformed_event
        )

      :skip ->
        :ok
    end
  end

  def handle(_, _), do: :ok
end
```

**Note:** We still pass the original event to `EventTransformer.transform/2` because it needs the struct type for `derive_event_type/1` and `AnimationDelays.for_event/1`. The sanitized data from the protocol is used as the gate — if the protocol says `:skip`, we don't broadcast at all.

- [ ] **Step 2: Run the full test suite**

Run: `mix test`
Expected: All tests PASS (no behavioral change for broadcast events, skipped events were never consumed meaningfully)

- [ ] **Step 3: Commit**

```bash
git add lib/poker/tables/event_handlers/table_event_broadcaster.ex
git commit -m "feat: use Broadcastable protocol in TableEventBroadcaster"
```

---

### Task 4: Strip sensitive fields from EventTransformer output

The broadcaster still passes the full event struct to `EventTransformer.transform/2`, which calls `Map.from_struct(event)` — meaning `hole_cards` would still end up in the broadcast data for `ParticipantHandGiven`. We need to use the sanitized data from the protocol in the transform step.

**Files:**
- Modify: `lib/poker/tables/event_handlers/table_event_broadcaster.ex`
- Modify: `lib/poker/tables/event_transformer.ex`

- [ ] **Step 1: Add a test for the transformer with pre-sanitized data**

Add to `test/poker/tables/events/broadcastable_test.exs`:

```elixir
describe "integration with EventTransformer" do
  alias Poker.Tables.EventTransformer

  test "ParticipantHandGiven broadcast data has no hole_cards after transform" do
    event = %Poker.Tables.Events.ParticipantHandGiven{
      id: "p1",
      table_id: "t1",
      participant_id: "part1",
      hand_id: "h1",
      hole_cards: [{:ace, :spades}, {:king, :hearts}],
      position: :dealer,
      status: :active,
      bet_this_round: 0,
      total_bet_this_hand: 0
    }

    metadata = %{event_id: "evt1", stream_version: 1}
    {:broadcast, sanitized} = Broadcastable.for_broadcast(event)
    transformed = EventTransformer.transform_sanitized(sanitized, event, metadata)

    refute Map.has_key?(transformed, :hole_cards)
    assert transformed.type == "ParticipantHandGiven"
    assert transformed.participant_id == "part1"
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/poker/tables/events/broadcastable_test.exs`
Expected: FAIL — `transform_sanitized/3` not defined

- [ ] **Step 3: Add `transform_sanitized/3` to EventTransformer**

Add to `lib/poker/tables/event_transformer.ex`:

```elixir
@doc """
Transforms pre-sanitized event data for broadcast.
Uses the sanitized map as the base, but derives type and timing from the original event struct.
"""
def transform_sanitized(sanitized_data, original_event, %{event_id: event_id, stream_version: stream_version})
    when is_struct(original_event) do
  event_type = derive_event_type(original_event)

  sanitized_data
  |> Map.put(:type, event_type)
  |> Map.put(:event_id, event_id)
  |> Map.put(:stream_version, stream_version)
  |> Map.put(:timing, AnimationDelays.for_event(original_event))
end
```

- [ ] **Step 4: Update the broadcaster to use `transform_sanitized/3`**

In `lib/poker/tables/event_handlers/table_event_broadcaster.ex`, change the `{:broadcast, _}` branch:

```elixir
{:broadcast, sanitized_data} ->
  transformed_event = EventTransformer.transform_sanitized(sanitized_data, event, metadata)

  Poker.Tables.PubSub.broadcast_table(
    event.table_id,
    transformed_event.type,
    transformed_event
  )
```

- [ ] **Step 5: Run all tests**

Run: `mix test`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add lib/poker/tables/event_transformer.ex lib/poker/tables/event_handlers/table_event_broadcaster.ex test/poker/tables/events/broadcastable_test.exs
git commit -m "feat: use sanitized data in broadcast transform pipeline"
```

---

### Task 5: Verify the HandReplay path is unaffected

The `EventTransformer` is also used by `HandReplay` for replay mode. The existing `transform/1` and `transform/2` functions must remain unchanged — replay shows all events including sensitive ones (it's server-side only for the player who played them).

**Files:**
- Read: `lib/poker/tables/views/hand_replay.ex` (verify it uses `transform/1` or `transform/2`, not the new function)

- [ ] **Step 1: Verify HandReplay doesn't use the new function**

Run: `grep -n "transform" lib/poker/tables/views/hand_replay.ex`
Expected: Uses `EventTransformer.transform/1` — the original function. No changes needed.

- [ ] **Step 2: Run the full test suite one final time**

Run: `mix test`
Expected: All tests PASS

- [ ] **Step 3: Commit (if any cleanup needed, otherwise skip)**

```bash
git add -A
git commit -m "chore: verify replay path unaffected by Broadcastable protocol"
```
