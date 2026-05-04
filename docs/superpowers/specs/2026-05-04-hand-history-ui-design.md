# Hand History UI — Design Spec

**Date:** 2026-05-04

---

## Overview

Add a global hand history page where a player can browse all hands they were dealt into across all cash games and tournaments. Also fix the replay route to support linking directly to a specific hand by `hand_id`.

---

## What We're Building

1. **Add `player_id` to `PayoutDistributed` event** — denormalize at the source so projectors are self-contained.
2. **Two new projections** — `hand_summaries` and `hand_summary_participant_results` — that materialize display-ready data at write time so the list query is a simple SQL read with no event stream scanning.
3. **A new LiveView page** — `/history` — showing the player's hand history as a filterable list.
4. **A replay route fix** — `/tables/:id/replay?hand=:hand_id` — so history rows can link directly to any hand, not just the most recent one.

---

## Event Change: `PayoutDistributed`

Add `player_id` field to `Poker.Tables.Events.PayoutDistributed`.

The aggregate already has `player_id` per participant — it will be included when emitting `PayoutDistributed` events. This is a non-breaking addition (existing event store records without it will decode `player_id` as `nil`).

---

## Projections

### `hand_summaries`

One row per completed hand. Inserted at `HandFinished` time, updated as `PayoutDistributed` events arrive.

| Field | Type | Source |
|-------|------|--------|
| `id` | uuid (PK) | generated |
| `hand_id` | binary_id | `HandFinished.hand_id` |
| `table_id` | binary_id | `HandFinished.table_id` |
| `game_mode` | enum (:cash_game, :tournament) | `TableList` projection at project time |
| `source_id` | binary_id, nullable | tournament id (from `TableList.source_id`) or nil for cash |
| `pot_total` | integer, default 0 | accumulated from `PayoutDistributed.amount` |
| `finish_reason` | atom | `HandFinished.finish_reason` |
| `winner_participant_id` | binary_id, nullable | participant who won the main pot |
| `winner_hand_rank` | string, nullable | encoded hand rank string, nil on fold |
| `inserted_at` / `updated_at` | timestamps | |

Indexes: `hand_id` (unique), `table_id`, `inserted_at desc`.

### `hand_summary_participant_results`

One row per player per hand. Upserted from `PayoutDistributed` events.

| Field | Type | Source |
|-------|------|--------|
| `id` | uuid (PK) | generated |
| `hand_id` | binary_id | `PayoutDistributed.hand_id` |
| `table_id` | binary_id | `PayoutDistributed.table_id` |
| `participant_id` | binary_id | `PayoutDistributed.participant_id` |
| `player_id` | binary_id | `PayoutDistributed.player_id` (new field) |
| `amount_won` | integer, default 0 | sum of `PayoutDistributed.amount` for this participant |
| `inserted_at` / `updated_at` | timestamps | |

Indexes: `player_id`, `hand_id`, composite `(hand_id, participant_id)` unique.

`amount_won = 0` means the player lost (received no payout). Display as a loss in the UI.

---

## Projector

`Poker.Tables.Projectors.HandSummary` listens to:

- `HandFinished` — insert `hand_summaries` row; look up `game_mode` and `source_id` from `TableList` projection at project time
- `PayoutDistributed` — upsert `hand_summary_participant_results` row accumulating `amount_won`; increment `pot_total` on the matching `hand_summaries` row; set `winner_participant_id` / `winner_hand_rank` when `pot_type == :main`

Uses `Ecto.Multi` for transactional updates per event.

Registered in `Poker.Tables.Supervisor`.

---

## Query

`Poker.Tables.Queries.HandHistory` module:

```elixir
def list_for_player(player_id, opts \\ []) do
  # join hand_summaries with hand_summary_participant_results on hand_id
  # where participant_results.player_id == player_id
  # order by hand_summaries.inserted_at desc
  # optionally filter by game_mode via opts[:game_mode]
  # limit/offset pagination via opts[:limit] / opts[:offset]
end
```

Returns structs/maps with all display fields — no event stream access at read time.

---

## UI — `/history`

New LiveView: `PokerWeb.PlayerLive.HandHistory`

- New sidebar link "History" in the `Dashboard` layout (under the PLAY section)
- Route: `live "/history", PlayerLive.HandHistory, :index` in the `:common` live_session
- Matches existing dashboard visual style (same header, sidebar, font variables)

### List columns

| Column | Display |
|--------|---------|
| When | Relative time (e.g. "2 hours ago") |
| Context | Badge: "Cash" or "Tournament", links to the table/tournament lobby |
| Pot | Total pot in chips |
| Result | Winner + hand rank if showdown, "No showdown" if folded |
| Won | Amount won (greyed out 0 if lost) |
| Finish | finish_reason label |
| Action | "Replay" link → `/tables/:table_id/replay?hand=:hand_id` |

Empty state: "No hands played yet."

---

## Replay Route Fix

**Current:** `PlayerLive.Replay` mounts and always calls `HandReplay.initialize(table_id, player_id, :previous)` — no way to link to a specific hand.

**Fix:** Add `handle_params/3` that reads the optional `hand` query param:
- `?hand=:hand_id` present → `HandReplay.initialize(table_id, player_id, hand_id)`
- No param → `HandReplay.initialize(table_id, player_id, :previous)` (existing behavior preserved)

`HandReplay.initialize/3` already supports binary `hand_id` — no changes needed there.

---

## What Is NOT Changing

- `hand_histories` projection and projector — untouched
- `HandEvents` queries — untouched
- Per-table lobby/replay pages — untouched except the query-param fix above

---

## Checklist

- [ ] Add `player_id` to `PayoutDistributed` event struct and Jason encoder
- [ ] Emit `player_id` in aggregate when producing `PayoutDistributed` events
- [ ] Migration: `create_hand_summaries`
- [ ] Migration: `create_hand_summary_participant_results`
- [ ] Projection: `Poker.Tables.Projections.HandSummary`
- [ ] Projection: `Poker.Tables.Projections.HandSummaryParticipantResult`
- [ ] Projector: `Poker.Tables.Projectors.HandSummary`
- [ ] Register projector in `Poker.Tables.Supervisor`
- [ ] Query module: `Poker.Tables.Queries.HandHistory`
- [ ] LiveView: `PokerWeb.PlayerLive.HandHistory`
- [ ] Router: add `/history` route
- [ ] Dashboard: add "History" sidebar link
- [ ] Replay fix: read `?hand=` query param in `PlayerLive.Replay`
