# Hand History UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global hand history page at `/history` showing all hands a player was dealt into, backed by two new projections (`hand_summaries`, `hand_summary_participant_results`) populated in real time from events.

**Architecture:** Add `player_id` to `ParticipantHandGiven` and `PayoutDistributed` events. A new `HandSummary` projector builds two projection tables as hands play out: one summary row per hand, one result row per participant. A query module joins them for the history list. The replay LiveView gains a `?hand=` query param so history rows can link directly to any hand.

**Tech Stack:** Elixir/Phoenix, Commanded (event sourcing), Ecto/PostgreSQL, Phoenix LiveView

---

## File Map

### New files
| File | Responsibility |
|------|----------------|
| `priv/repo/migrations/20260504125910_create_hand_summaries.exs` | DB table for hand summary rows |
| `priv/repo/migrations/20260504125916_create_hand_summary_participant_results.exs` | DB table for per-participant results |
| `lib/poker/tables/projections/hand_summary.ex` | Ecto schema for hand_summaries |
| `lib/poker/tables/projections/hand_summary_participant_result.ex` | Ecto schema for hand_summary_participant_results |
| `lib/poker/tables/projectors/hand_summary.ex` | Commanded projector populating both tables |
| `lib/poker/tables/queries/hand_history.ex` | `list_for_player/2` query |
| `lib/poker_web/live/player_live/hand_history.ex` | `/history` LiveView |
| `test/poker/tables/projectors/hand_summary_test.exs` | Projector tests |

### Modified files
| File | Change |
|------|--------|
| `lib/poker/tables/events/participant_hand_given.ex` | Add `player_id` field |
| `lib/poker/tables/events/payout_distributed.ex` | Add `player_id` field |
| `lib/poker/tables/aggregates/table/handlers/hand.ex` | Pass `player_id` in both events |
| `lib/poker/tables/supervisor.ex` | Register `HandSummary` projector |
| `lib/poker_web/router.ex` | Add `live "/history"` route |
| `lib/poker_web/live/player_live/dashboard.ex` | Add "History" sidebar link |
| `lib/poker_web/live/player_live/replay.ex` | Read `?hand=` query param |

---

## Task 1: Add `player_id` to `ParticipantHandGiven` event

**Files:**
- Modify: `lib/poker/tables/events/participant_hand_given.ex`
- Modify: `lib/poker/tables/aggregates/table/handlers/hand.ex`

- [ ] **Step 1: Add `player_id` to event struct and Jason.Encoder**

In `lib/poker/tables/events/participant_hand_given.ex`, replace the entire file:

```elixir
defmodule Poker.Tables.Events.ParticipantHandGiven do
  @derive {Jason.Encoder,
           only: [
             :id,
             :table_id,
             :participant_id,
             :player_id,
             :hand_id,
             :hole_cards,
             :position,
             :status,
             :bet_this_round,
             :total_bet_this_hand
           ]}
  defstruct [
    :id,
    :table_id,
    :participant_id,
    :player_id,
    :hand_id,
    :hole_cards,
    :position,
    :status,
    :bet_this_round,
    :total_bet_this_hand
  ]
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.ParticipantHandGiven do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.ParticipantHandGiven{} = event) do
    %Poker.Tables.Events.ParticipantHandGiven{
      event
      | status: AtomDecoder.decode(:participant_status, event.status),
        position: AtomDecoder.decode(:participant_position, event.position),
        hole_cards: AtomDecoder.decode_cards(event.hole_cards)
    }
  end
end
```

- [ ] **Step 2: Emit `player_id` in the aggregate when dealing hole cards**

In `lib/poker/tables/aggregates/table/handlers/hand.ex`, inside `deal_hole_cards/2`, the `ParticipantHandGiven` struct is built. Add `player_id: participant.player_id`:

```elixir
new_events = [
  %ParticipantHandGiven{
    id: UUIDv7.generate(),
    table_id: table.id,
    participant_id: participant.id,
    player_id: participant.player_id,
    hand_id: hand_id,
    hole_cards: hole_cards,
    position: position,
    status: :playing,
    bet_this_round: 0,
    total_bet_this_hand: 0
  },
  %DeckUpdated{
    hand_id: hand_id,
    table_id: table.id,
    cards: remaining_deck
  }
]
```

- [ ] **Step 3: Compile and verify no errors**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/poker/tables/events/participant_hand_given.ex lib/poker/tables/aggregates/table/handlers/hand.ex
git commit -m "feat: add player_id to ParticipantHandGiven event"
```

---

## Task 2: Add `player_id` to `PayoutDistributed` event

**Files:**
- Modify: `lib/poker/tables/events/payout_distributed.ex`
- Modify: `lib/poker/tables/aggregates/table/handlers/hand.ex`

- [ ] **Step 1: Add `player_id` to `PayoutDistributed` struct and Jason encoder**

In `lib/poker/tables/events/payout_distributed.ex`, replace the entire file:

```elixir
defmodule Poker.Tables.Events.PayoutDistributed do
  defstruct [:table_id, :hand_id, :pot_id, :participant_id, :player_id, :amount, :pot_type, :hand_rank]
end

defimpl Jason.Encoder, for: Poker.Tables.Events.PayoutDistributed do
  def encode(event, opts) do
    event
    |> Map.from_struct()
    |> Map.update(:hand_rank, nil, &encode_hand_rank/1)
    |> Jason.Encode.map(opts)
  end

  defp encode_hand_rank(nil), do: nil
  defp encode_hand_rank(tuple) when is_tuple(tuple), do: Poker.Services.HandRank.encode(tuple)
  defp encode_hand_rank(list) when is_list(list), do: list
end

defimpl Commanded.Serialization.JsonDecoder, for: Poker.Tables.Events.PayoutDistributed do
  alias Poker.Tables.AtomDecoder

  def decode(%Poker.Tables.Events.PayoutDistributed{} = event) do
    %{event |
      pot_type: AtomDecoder.decode(:pot_type, event.pot_type),
      hand_rank: AtomDecoder.decode(:hand_rank, event.hand_rank)
    }
  end
end
```

- [ ] **Step 2: Emit `player_id` in `finish_hand(:all_folded)`**

In `lib/poker/tables/aggregates/table/handlers/hand.ex`, in the `finish_hand(table, :all_folded)` clause, look up the winner's `player_id` from `table.participants` and include it:

```elixir
defp finish_hand(table, :all_folded = reason) do
  table
  |> Commanded.Aggregate.Multi.new()
  |> Commanded.Aggregate.Multi.execute(fn %{
                                            hand: %{id: hand_id},
                                            pots: pots,
                                            participant_hands: participant_hands
                                          } = table ->
    active_participant_hand =
      Enum.find(participant_hands, fn hand -> hand.status != :folded end)

    winner_participant_id =
      if active_participant_hand do
        active_participant_hand.participant_id
      else
        participant_hands
        |> Enum.filter(fn hand -> hand.folded_at != nil end)
        |> Enum.max_by(fn hand -> hand.folded_at end, DateTime)
        |> then(& &1.participant_id)
      end

    winner_player_id =
      table.participants
      |> Enum.find(fn p -> p.id == winner_participant_id end)
      |> then(& &1.player_id)

    total_amount = Enum.reduce(pots, 0, fn pot, acc -> acc + pot.amount end)

    %PayoutDistributed{
      table_id: table.id,
      hand_id: hand_id,
      pot_id: nil,
      participant_id: winner_participant_id,
      player_id: winner_player_id,
      amount: total_amount,
      pot_type: :combined,
      hand_rank: nil
    }
  end)
  |> Commanded.Aggregate.Multi.execute(&handle_zero_chip_participants/1)
  |> Commanded.Aggregate.Multi.execute(fn %{hand: %{id: hand_id}} ->
    %HandFinished{
      table_id: table.id,
      hand_id: hand_id,
      finish_reason: reason
    }
  end)
end
```

- [ ] **Step 3: Emit `player_id` in `finish_hand(:showdown)`**

In the same file, in the `finish_hand(table, :showdown)` clause, the `PayoutDistributed` struct inside the `Enum.flat_map` needs `player_id`. Look it up from `table.participants` (note: `table` is captured in the outer function via the pattern match on `%{...} = table` — but the current code matches `%{hand: ..., pots: ..., participant_hands: ..., community_cards: ...}` without binding `table`. We need to also capture the participants. Replace the `fn %{hand:..., pots:..., participant_hands:..., community_cards:...} ->` pattern to also bind `table`:

```elixir
|> Commanded.Aggregate.Multi.execute(fn %{
                                          hand: %{id: hand_id},
                                          pots: pots,
                                          participant_hands: participant_hands,
                                          community_cards: community_cards
                                        } = table ->
  Enum.flat_map(pots, fn pot ->
    contributing_participant_hands =
      participant_hands
      |> Enum.filter(&(&1.participant_id in pot.contributing_participant_ids))

    winners =
      Poker.Services.HandEvaluator.determine_winners(
        contributing_participant_hands,
        community_cards
      )

    winner_count = length(winners)
    split_amount = div(pot.amount, winner_count)
    remainder = rem(pot.amount, winner_count)

    winners
    |> Enum.with_index()
    |> Enum.map(fn {winner, index} ->
      amount = if index == 0, do: split_amount + remainder, else: split_amount

      winner_player_id =
        table.participants
        |> Enum.find(fn p -> p.id == winner.participant_id end)
        |> then(& &1.player_id)

      %PayoutDistributed{
        table_id: table.id,
        hand_id: hand_id,
        pot_id: pot.id,
        participant_id: winner.participant_id,
        player_id: winner_player_id,
        amount: amount,
        pot_type: pot.type,
        hand_rank: winner.hand_rank
      }
    end)
  end)
end)
```

- [ ] **Step 4: Compile and verify no errors**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/poker/tables/events/payout_distributed.ex lib/poker/tables/aggregates/table/handlers/hand.ex
git commit -m "feat: add player_id to PayoutDistributed event"
```

---

## Task 3: Migrations

**Files:**
- Create: `priv/repo/migrations/20260504125910_create_hand_summaries.exs`
- Create: `priv/repo/migrations/20260504125916_create_hand_summary_participant_results.exs`

- [ ] **Step 1: Create hand_summaries migration**

```elixir
# priv/repo/migrations/20260504125910_create_hand_summaries.exs
defmodule Poker.Repo.Migrations.CreateHandSummaries do
  use Ecto.Migration

  def change do
    create table(:hand_summaries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, :binary_id, null: false
      add :table_id, :binary_id, null: false
      add :game_mode, :string, null: false
      add :source_id, :binary_id
      add :pot_total, :integer, null: false, default: 0
      add :finish_reason, :string
      add :winner_participant_id, :binary_id
      add :winner_player_id, :binary_id
      add :winner_hand_rank, :string

      timestamps()
    end

    create unique_index(:hand_summaries, [:hand_id])
    create index(:hand_summaries, [:table_id])
    create index(:hand_summaries, [:inserted_at])
  end
end
```

- [ ] **Step 2: Create hand_summary_participant_results migration**

```elixir
# priv/repo/migrations/20260504125916_create_hand_summary_participant_results.exs
defmodule Poker.Repo.Migrations.CreateHandSummaryParticipantResults do
  use Ecto.Migration

  def change do
    create table(:hand_summary_participant_results, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hand_id, :binary_id, null: false
      add :table_id, :binary_id, null: false
      add :participant_id, :binary_id, null: false
      add :player_id, :binary_id, null: false
      add :amount_won, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:hand_summary_participant_results, [:hand_id, :participant_id])
    create index(:hand_summary_participant_results, [:player_id])
    create index(:hand_summary_participant_results, [:hand_id])
  end
end
```

- [ ] **Step 3: Run migrations**

```bash
mix ecto.migrate
```

Expected output: `== Running ... CreateHandSummaries == ... done` and `== Running ... CreateHandSummaryParticipantResults == ... done`

- [ ] **Step 4: Commit**

```bash
git add priv/repo/migrations/20260504125910_create_hand_summaries.exs priv/repo/migrations/20260504125916_create_hand_summary_participant_results.exs
git commit -m "feat: add hand_summaries and hand_summary_participant_results migrations"
```

---

## Task 4: Projection schemas

**Files:**
- Create: `lib/poker/tables/projections/hand_summary.ex`
- Create: `lib/poker/tables/projections/hand_summary_participant_result.ex`

- [ ] **Step 1: Create `HandSummary` schema**

```elixir
# lib/poker/tables/projections/hand_summary.ex
defmodule Poker.Tables.Projections.HandSummary do
  use Poker, :schema

  schema "hand_summaries" do
    field :hand_id, :binary_id
    field :table_id, :binary_id
    field :game_mode, Ecto.Enum, values: [:cash_game, :tournament]
    field :source_id, :binary_id
    field :pot_total, :integer, default: 0
    field :finish_reason, Ecto.Enum, values: [:showdown, :all_in_runout, :all_folded]
    field :winner_participant_id, :binary_id
    field :winner_player_id, :binary_id
    field :winner_hand_rank, :string

    timestamps()
  end
end
```

- [ ] **Step 2: Create `HandSummaryParticipantResult` schema**

```elixir
# lib/poker/tables/projections/hand_summary_participant_result.ex
defmodule Poker.Tables.Projections.HandSummaryParticipantResult do
  use Poker, :schema

  schema "hand_summary_participant_results" do
    field :hand_id, :binary_id
    field :table_id, :binary_id
    field :participant_id, :binary_id
    field :player_id, :binary_id
    field :amount_won, :integer, default: 0

    timestamps()
  end
end
```

- [ ] **Step 3: Compile and verify**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/poker/tables/projections/hand_summary.ex lib/poker/tables/projections/hand_summary_participant_result.ex
git commit -m "feat: add HandSummary and HandSummaryParticipantResult projection schemas"
```

---

## Task 5: HandSummary projector

**Files:**
- Create: `lib/poker/tables/projectors/hand_summary.ex`
- Modify: `lib/poker/tables/supervisor.ex`

The projector listens to four events in sequence:
1. `HandStarted` → insert `hand_summaries` row (looks up `game_mode`/`source_id` from `TableList`)
2. `ParticipantHandGiven` → insert `hand_summary_participant_results` row with `amount_won: 0`
3. `PayoutDistributed` → update participant result `amount_won`; update hand_summary `pot_total` and winner fields (when `pot_type` is `:main` or `:combined`)
4. `HandFinished` → update hand_summary with `finish_reason`

- [ ] **Step 1: Create the projector**

```elixir
# lib/poker/tables/projectors/hand_summary.ex
defmodule Poker.Tables.Projectors.HandSummary do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__,
    consistency: :strong

  import Ecto.Query

  alias Poker.Tables.Events.{
    HandStarted,
    ParticipantHandGiven,
    PayoutDistributed,
    HandFinished
  }

  alias Poker.Tables.Projections.{
    HandSummary,
    HandSummaryParticipantResult,
    TableList
  }

  # Insert a summary row when the hand starts.
  # Look up game_mode and source_id from TableList (already populated with strong consistency).
  project(%HandStarted{id: hand_id, table_id: table_id}, fn multi ->
    multi
    |> Ecto.Multi.run(:table_info, fn repo, _changes ->
      case repo.get(TableList, table_id) do
        nil -> {:error, :table_not_found}
        table -> {:ok, table}
      end
    end)
    |> Ecto.Multi.insert(:hand_summary, fn %{table_info: table} ->
      %HandSummary{
        id: Ecto.UUID.generate(),
        hand_id: hand_id,
        table_id: table_id,
        game_mode: table.game_mode,
        source_id: table.source_id,
        pot_total: 0
      }
    end)
  end)

  # Insert participant result row when cards are dealt.
  # player_id is now included in the event directly.
  project(%ParticipantHandGiven{hand_id: hand_id, table_id: table_id, participant_id: participant_id, player_id: player_id}, fn multi ->
    Ecto.Multi.insert(multi, :participant_result, %HandSummaryParticipantResult{
      id: Ecto.UUID.generate(),
      hand_id: hand_id,
      table_id: table_id,
      participant_id: participant_id,
      player_id: player_id,
      amount_won: 0
    })
  end)

  # Accumulate pot_total and participant amount_won.
  # Set winner fields when the main or combined pot is distributed.
  project(%PayoutDistributed{} = event, fn multi ->
    multi
    |> Ecto.Multi.update_all(
      :increment_participant_amount,
      from(r in HandSummaryParticipantResult,
        where: r.hand_id == ^event.hand_id and r.participant_id == ^event.participant_id
      ),
      inc: [amount_won: event.amount]
    )
    |> Ecto.Multi.update_all(
      :increment_pot_total,
      from(s in HandSummary, where: s.hand_id == ^event.hand_id),
      inc: [pot_total: event.amount]
    )
    |> maybe_set_winner(event)
  end)

  # Set finish_reason when the hand ends.
  project(%HandFinished{hand_id: hand_id, finish_reason: finish_reason}, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :set_finish_reason,
      from(s in HandSummary, where: s.hand_id == ^hand_id),
      set: [finish_reason: finish_reason]
    )
  end)

  # Set winner fields on the hand_summary when the main or combined pot is paid out.
  defp maybe_set_winner(multi, %PayoutDistributed{pot_type: pot_type} = event)
       when pot_type in [:main, :combined] do
    encoded_rank = encode_hand_rank(event.hand_rank)

    Ecto.Multi.update_all(
      multi,
      :set_winner,
      from(s in HandSummary, where: s.hand_id == ^event.hand_id),
      set: [
        winner_participant_id: event.participant_id,
        winner_player_id: event.player_id,
        winner_hand_rank: encoded_rank
      ]
    )
  end

  defp maybe_set_winner(multi, _event), do: multi

  defp encode_hand_rank(nil), do: nil
  defp encode_hand_rank(rank) when is_tuple(rank), do: Poker.Services.HandRank.encode(rank)
end
```

- [ ] **Step 2: Register the projector in the supervisor**

In `lib/poker/tables/supervisor.ex`, add `Tables.Projectors.HandSummary` to the children list:

```elixir
def init(_arg) do
  Supervisor.init(
    [
      Tables.EventHandlers.EventBroadcaster,
      Tables.Projectors.TableList,
      Tables.Projectors.TableLobby,
      Tables.Projectors.HandHistory,
      Tables.Projectors.HandSummary,
      Tables.ProcessManager
    ],
    strategy: :one_for_one
  )
end
```

- [ ] **Step 3: Compile**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/poker/tables/projectors/hand_summary.ex lib/poker/tables/supervisor.ex
git commit -m "feat: add HandSummary projector"
```

---

## Task 6: Projector tests

**Files:**
- Create: `test/poker/tables/projectors/hand_summary_test.exs`

- [ ] **Step 1: Write tests**

```elixir
# test/poker/tables/projectors/hand_summary_test.exs
defmodule Poker.Tables.Projectors.HandSummaryTest do
  use Poker.DataCase

  alias Poker.Tables.Projections.HandSummary
  alias Poker.Tables.Projections.HandSummaryParticipantResult

  alias Poker.Tables.Events.{
    HandStarted,
    HandFinished,
    PayoutDistributed
  }

  describe "hand lifecycle - all_folded" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "creates hand_summary on HandStarted", ctx do
      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      hand_id = ctx.table.hand.id
      summary = Repo.get_by(HandSummary, hand_id: hand_id)

      assert summary != nil
      assert summary.hand_id == hand_id
      assert summary.table_id == ctx.table.id
      assert summary.game_mode == :tournament
      assert summary.pot_total == 0
      assert summary.finish_reason == nil
    end

    test "creates participant results on hand dealt", ctx do
      assert_receive_event(Poker.App, HandStarted, fn event ->
        assert event.table_id == ctx.table.id
      end)

      hand_id = ctx.table.hand.id
      results = Repo.all(from r in HandSummaryParticipantResult, where: r.hand_id == ^hand_id)

      assert length(results) == 2
      assert Enum.all?(results, fn r -> r.amount_won == 0 end)
      assert Enum.all?(results, fn r -> r.player_id != nil end)
    end

    test "sets winner and pot_total on PayoutDistributed, finish_reason on HandFinished", ctx do
      hand_id = ctx.table.hand.id

      ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      summary = Repo.get_by(HandSummary, hand_id: hand_id)

      assert summary.finish_reason == :all_folded
      assert summary.pot_total > 0
      assert summary.winner_participant_id != nil
      assert summary.winner_player_id != nil
      # all_folded: no hand rank
      assert summary.winner_hand_rank == nil
    end

    test "winner participant result has amount_won > 0", ctx do
      hand_id = ctx.table.hand.id

      ctx |> exec(:fold_hand, position: :dealer)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      summary = Repo.get_by(HandSummary, hand_id: hand_id)
      winner_result =
        Repo.get_by(HandSummaryParticipantResult,
          hand_id: hand_id,
          participant_id: summary.winner_participant_id
        )

      assert winner_result.amount_won > 0
    end
  end

  describe "hand lifecycle - showdown" do
    setup ctx do
      ctx
      |> exec(:create_tournament, settings: %{speed: :hyper_turbo, buy_in: 100, table_type: :two_max})
      |> exec(:fill_tournament)
    end

    test "sets winner_hand_rank on showdown finish", ctx do
      hand_id = ctx.table.hand.id

      ctx
      |> exec(:post_small_blind)
      |> exec(:post_big_blind)
      |> exec(:call_hand, position: :dealer)
      |> exec(:check_hand, position: :big_blind)
      |> exec(:check_hand, position: :dealer)
      |> exec(:check_hand, position: :big_blind)
      |> exec(:check_hand, position: :dealer)
      |> exec(:check_hand, position: :big_blind)
      |> exec(:check_hand, position: :dealer)
      |> exec(:check_hand, position: :big_blind)

      assert_receive_event(Poker.App, HandFinished, fn event ->
        assert event.hand_id == hand_id
      end)

      summary = Repo.get_by(HandSummary, hand_id: hand_id)

      assert summary.finish_reason == :showdown
      assert summary.pot_total > 0
      assert summary.winner_participant_id != nil
      # showdown: hand rank is set
      assert summary.winner_hand_rank != nil
    end
  end
end
```

- [ ] **Step 2: Run the tests**

```bash
mix test test/poker/tables/projectors/hand_summary_test.exs
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/poker/tables/projectors/hand_summary_test.exs
git commit -m "test: add HandSummary projector tests"
```

---

## Task 7: Query module

**Files:**
- Create: `lib/poker/tables/queries/hand_history.ex`

- [ ] **Step 1: Create the query module**

```elixir
# lib/poker/tables/queries/hand_history.ex
defmodule Poker.Tables.Queries.HandHistory do
  @moduledoc """
  Queries for the global hand history list.

  Uses hand_summaries joined with hand_summary_participant_results to return
  all hands a player was dealt into, with per-hand display data.
  """

  import Ecto.Query

  alias Poker.Tables.Projections.HandSummary
  alias Poker.Tables.Projections.HandSummaryParticipantResult

  @default_limit 20

  @doc """
  List all hands a player was dealt into, most recent first.

  ## Options
    * `:game_mode` - filter by `:cash_game` or `:tournament`
    * `:limit` - number of results (default 20)
    * `:offset` - pagination offset (default 0)

  ## Returns

  List of maps with keys:
    `:hand_id`, `:table_id`, `:game_mode`, `:source_id`,
    `:pot_total`, `:finish_reason`, `:winner_player_id`,
    `:winner_hand_rank`, `:amount_won`, `:inserted_at`
  """
  def list_for_player(player_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, 0)
    game_mode = Keyword.get(opts, :game_mode)

    base_query =
      from summary in HandSummary,
        join: result in HandSummaryParticipantResult,
        on: result.hand_id == summary.hand_id and result.player_id == ^player_id,
        order_by: [desc: summary.inserted_at],
        limit: ^limit,
        offset: ^offset,
        select: %{
          hand_id: summary.hand_id,
          table_id: summary.table_id,
          game_mode: summary.game_mode,
          source_id: summary.source_id,
          pot_total: summary.pot_total,
          finish_reason: summary.finish_reason,
          winner_player_id: summary.winner_player_id,
          winner_hand_rank: summary.winner_hand_rank,
          amount_won: result.amount_won,
          inserted_at: summary.inserted_at
        }

    query =
      if game_mode do
        where(base_query, [summary, _result], summary.game_mode == ^game_mode)
      else
        base_query
      end

    Poker.Repo.all(query)
  end
end
```

- [ ] **Step 2: Compile**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/poker/tables/queries/hand_history.ex
git commit -m "feat: add HandHistory query module"
```

---

## Task 8: Replay route fix

**Files:**
- Modify: `lib/poker_web/live/player_live/replay.ex`

Currently `mount/3` always loads `:previous`. The fix: move hand loading into `handle_params/3` and read the optional `hand` query param.

- [ ] **Step 1: Update `PlayerLive.Replay` to read `?hand=` param**

Replace the `mount/3` and add `handle_params/3` in `lib/poker_web/live/player_live/replay.ex`:

```elixir
@impl true
def mount(%{"id" => table_id}, _session, socket) do
  lobby = Tables.get_lobby(table_id)

  if is_nil(lobby) do
    {:ok,
     socket
     |> put_flash(:error, "Table not found")
     |> push_navigate(to: ~p"/")}
  else
    table = Poker.Repo.get(Poker.Tables.Projections.TableList, table_id)

    lobby_path =
      case table do
        %{game_mode: :tournament, source_id: tid} when is_binary(tid) -> ~p"/tournaments/#{tid}/lobby"
        _ -> ~p"/cash/#{table_id}/lobby"
      end

    {:ok,
     assign(socket,
       table_id: table_id,
       lobby_path: lobby_path,
       replay: nil,
       current_user_id: socket.assigns.current_scope.user.id,
       playing: false
     )}
  end
end

@impl true
def handle_params(params, _uri, socket) do
  if socket.assigns.replay == nil do
    table_id = socket.assigns.table_id
    player_id = socket.assigns.current_user_id

    hand_id = Map.get(params, "hand", :previous)

    replay = HandReplay.initialize(table_id, player_id, hand_id)

    socket =
      if replay.total_steps == 0 do
        put_flash(socket, :info, "No hand to replay")
      else
        socket
      end

    {:noreply, assign(socket, replay: replay)}
  else
    {:noreply, socket}
  end
end
```

Also update the `render/1` function — the `data-state` attribute accesses `@replay.current_state` which could be `nil` on initial mount before `handle_params` runs. Guard it:

```elixir
data-state={if @replay, do: JsonEncoder.transform_keys(@replay.current_state) |> Jason.encode!(), else: "{}"}
```

And update the step controls to only render when `@replay` is not nil:

```elixir
<%= if @replay do %>
  <div class="absolute bottom-4 right-4">
    ... (existing controls unchanged, just wrapped in if) ...
  </div>
<% end %>
```

And update the step count span:

```elixir
<span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)] ml-1">
  {@replay.current_step}/{@replay.total_steps}
</span>
```

And the disabled checks on buttons still reference `@replay.current_step` and `@replay.total_steps` — these are fine inside the `if @replay` block.

Also update `handle_event("step_forward", ...)` and `handle_event("step_backward", ...)` to guard against `nil` replay — though in practice they only fire after `handle_params` has run so this is defensive. No change needed there.

- [ ] **Step 2: Compile**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/poker_web/live/player_live/replay.ex
git commit -m "feat: support ?hand= query param in replay LiveView"
```

---

## Task 9: Hand history LiveView and routing

**Files:**
- Create: `lib/poker_web/live/player_live/hand_history.ex`
- Modify: `lib/poker_web/router.ex`
- Modify: `lib/poker_web/live/player_live/dashboard.ex`

- [ ] **Step 1: Create the HandHistory LiveView**

```elixir
# lib/poker_web/live/player_live/hand_history.ex
defmodule PokerWeb.PlayerLive.HandHistory do
  use PokerWeb, :live_view

  alias Poker.Tables.Queries.HandHistory

  @impl true
  def mount(_params, _session, socket) do
    player_id = socket.assigns.current_scope.user.id
    hands = HandHistory.list_for_player(player_id)

    {:ok,
     assign(socket,
       hands: hands,
       player_id: player_id,
       active_tab: :all
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = case Map.get(params, "filter") do
      "cash" -> :cash_game
      "tournaments" -> :tournament
      _ -> nil
    end

    active_tab = case filter do
      :cash_game -> :cash
      :tournament -> :tournaments
      _ -> :all
    end

    hands = HandHistory.list_for_player(
      socket.assigns.player_id,
      game_mode: filter
    )

    {:noreply, assign(socket, hands: hands, active_tab: active_tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col font-[family-name:var(--pkr-font-ui)]">
      <!-- Top bar (reuse dashboard header style) -->
      <header class="h-14 flex items-center justify-between px-5 border-b border-[var(--pkr-line)]">
        <div class="flex items-center gap-3.5">
          <.link
            navigate={~p"/"}
            class="font-[family-name:var(--pkr-font-display)] text-[22px] italic flex items-baseline gap-1"
          >
            Poker
            <span class="text-[var(--pkr-ink-3)] text-[12px] not-italic font-[family-name:var(--pkr-font-mono)]">
              by Volodymyr Potiichuk
            </span>
          </.link>
        </div>
        <div class="flex items-center gap-3.5">
          <span class="text-xs text-[var(--pkr-ink-3)]">{@current_scope.user.email}</span>
          <.link
            href={~p"/users/settings"}
            class="px-3 py-1.5 rounded-md text-xs text-[var(--pkr-ink-2)] border border-[var(--pkr-line)] hover:bg-[var(--pkr-bg-2)] transition-all"
          >
            Settings
          </.link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="px-3 py-1.5 rounded-md text-xs text-[var(--pkr-danger)] border border-[var(--pkr-danger)]/40 hover:bg-[var(--pkr-danger)]/15 transition-all"
          >
            Log out
          </.link>
        </div>
      </header>

      <div class="flex flex-1 min-h-0">
        <!-- Sidebar -->
        <aside class="w-[260px] border-r border-[var(--pkr-line)] flex flex-col shrink-0">
          <div class="p-5 pb-3">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2">
              PLAY
            </div>
            <div class="flex flex-col gap-0.5">
              <.link
                navigate={~p"/cash"}
                class="flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50 transition-all"
              >
                <span class="w-4 text-center text-[var(--pkr-ink-3)]">&#x25D0;</span>
                <span class="flex-1">Cash games</span>
              </.link>
              <.link
                navigate={~p"/tournaments"}
                class="flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50 transition-all"
              >
                <span class="w-4 text-center text-[var(--pkr-ink-3)]">&#x25C7;</span>
                <span class="flex-1">Tournaments</span>
              </.link>
            </div>
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2 mt-4">
              HISTORY
            </div>
            <div class="flex flex-col gap-0.5">
              <.link
                patch={~p"/history"}
                class={"flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] transition-all " <>
                  if(@active_tab == :all,
                    do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border border-[var(--pkr-line)]",
                    else: "text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50"
                  )}
              >
                <span class={"w-4 text-center " <> if(@active_tab == :all, do: "text-[var(--pkr-accent)]", else: "text-[var(--pkr-ink-3)]")}>&#x2630;</span>
                <span class="flex-1">All hands</span>
                <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
                  {length(@hands)}
                </span>
              </.link>
              <.link
                patch={~p"/history?filter=cash"}
                class={"flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] transition-all " <>
                  if(@active_tab == :cash,
                    do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border border-[var(--pkr-line)]",
                    else: "text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50"
                  )}
              >
                <span class={"w-4 text-center " <> if(@active_tab == :cash, do: "text-[var(--pkr-accent)]", else: "text-[var(--pkr-ink-3)]")}>&#x25D0;</span>
                <span class="flex-1">Cash hands</span>
              </.link>
              <.link
                patch={~p"/history?filter=tournaments"}
                class={"flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] transition-all " <>
                  if(@active_tab == :tournaments,
                    do: "bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-1)] border border-[var(--pkr-line)]",
                    else: "text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50"
                  )}
              >
                <span class={"w-4 text-center " <> if(@active_tab == :tournaments, do: "text-[var(--pkr-accent)]", else: "text-[var(--pkr-ink-3)]")}>&#x25C7;</span>
                <span class="flex-1">Tournament hands</span>
              </.link>
            </div>
          </div>
        </aside>

        <!-- Main content -->
        <main class="flex-1 p-6 overflow-auto">
          <.flash kind={:error} flash={@flash} />
          <.flash kind={:info} flash={@flash} />

          <header class="mb-6">
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
              History
            </div>
            <h1 class="font-[family-name:var(--pkr-font-display)] text-[44px] leading-none text-[var(--pkr-ink-1)]">
              Hand History
            </h1>
            <p class="text-[var(--pkr-ink-3)] text-[13px] mt-1.5">
              All hands you've been dealt into.
            </p>
          </header>

          <.hand_history_table hands={@hands} />
        </main>
      </div>
    </div>
    """
  end

  defp hand_history_table(assigns) do
    ~H"""
    <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
      <div class="grid grid-cols-[0.5fr_1fr_0.7fr_1.2fr_0.6fr_0.6fr_0.5fr] px-4 py-2.5 border-b border-[var(--pkr-line)] font-[family-name:var(--pkr-font-mono)] text-[10px] tracking-[0.1em] text-[var(--pkr-ink-3)] uppercase">
        <span>WHEN</span>
        <span>CONTEXT</span>
        <span>POT</span>
        <span>RESULT</span>
        <span>WON</span>
        <span>FINISH</span>
        <span class="text-right">REPLAY</span>
      </div>

      <%= if Enum.empty?(@hands) do %>
        <div class="px-6 py-16 text-center">
          <p class="text-[var(--pkr-ink-3)] font-medium">No hands played yet.</p>
          <p class="text-sm text-[var(--pkr-ink-3)]/70 mt-1">Join a table and play some hands!</p>
        </div>
      <% else %>
        <%= for {hand, index} <- Enum.with_index(@hands) do %>
          <div class={"grid grid-cols-[0.5fr_1fr_0.7fr_1.2fr_0.6fr_0.6fr_0.5fr] px-4 py-3 items-center text-[13px] " <>
            if(index < length(@hands) - 1, do: "border-b border-dashed border-[var(--pkr-line)]", else: "")}>
            <!-- When -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
              {format_time(hand.inserted_at)}
            </span>
            <!-- Context -->
            <div class="flex items-center gap-2">
              <span class={"px-1.5 py-0.5 rounded text-[10px] font-[family-name:var(--pkr-font-mono)] font-medium " <>
                if(hand.game_mode == :cash_game, do: "bg-[var(--pkr-accent)]/20 text-[var(--pkr-accent)]", else: "bg-[var(--pkr-positive)]/20 text-[var(--pkr-positive)]")}>
                {if hand.game_mode == :cash_game, do: "CASH", else: "TOURN"}
              </span>
              <.link
                navigate={context_link(hand)}
                class="text-[var(--pkr-ink-2)] hover:text-[var(--pkr-accent)] transition-colors text-[12px] truncate"
              >
                {format_context(hand)}
              </.link>
            </div>
            <!-- Pot -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[var(--pkr-ink-1)]">
              ${hand.pot_total}
            </span>
            <!-- Result -->
            <span class="text-[var(--pkr-ink-2)] text-[12px]">
              {format_result(hand)}
            </span>
            <!-- Won -->
            <span class={"font-[family-name:var(--pkr-font-mono)] text-[13px] " <>
              if(hand.amount_won > 0, do: "text-[var(--pkr-positive)]", else: "text-[var(--pkr-ink-3)]")}>
              {if hand.amount_won > 0, do: "+#{hand.amount_won}", else: "—"}
            </span>
            <!-- Finish -->
            <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
              {format_finish_reason(hand.finish_reason)}
            </span>
            <!-- Replay -->
            <div class="text-right">
              <.link
                navigate={~p"/tables/#{hand.table_id}/replay?hand=#{hand.hand_id}"}
                class="px-2.5 py-1 rounded-md text-[11px] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] hover:bg-[var(--pkr-bg-2)] transition-all font-[family-name:var(--pkr-font-mono)]"
              >
                Replay
              </.link>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp format_time(nil), do: "—"
  defp format_time(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %H:%M")
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %H:%M")

  defp format_context(%{game_mode: :cash_game, table_id: id}), do: "Cash ##{String.slice(id, 0, 8)}"
  defp format_context(%{game_mode: :tournament, source_id: id}) when is_binary(id), do: "Tourney ##{String.slice(id, 0, 8)}"
  defp format_context(_), do: "—"

  defp context_link(%{game_mode: :cash_game, table_id: id}), do: ~p"/cash/#{id}/lobby"
  defp context_link(%{game_mode: :tournament, source_id: id}) when is_binary(id), do: ~p"/tournaments/#{id}/lobby"
  defp context_link(%{table_id: id}), do: ~p"/cash/#{id}/lobby"

  defp format_result(%{winner_hand_rank: nil, finish_reason: :all_folded}), do: "No showdown"
  defp format_result(%{winner_hand_rank: rank}) when is_binary(rank), do: rank
  defp format_result(_), do: "—"

  defp format_finish_reason(:showdown), do: "Showdown"
  defp format_finish_reason(:all_folded), do: "Fold"
  defp format_finish_reason(:all_in_runout), do: "All-in"
  defp format_finish_reason(nil), do: "—"
  defp format_finish_reason(_), do: "—"
end
```

- [ ] **Step 2: Add `/history` route to router**

In `lib/poker_web/router.ex`, inside the `:common` live_session block, add:

```elixir
live "/history", PlayerLive.HandHistory, :index
```

The block should look like:

```elixir
live_session :common,
  on_mount: [{PokerWeb.UserAuth, :require_authenticated}] do
  live "/users/settings", UserLive.Settings, :edit
  live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
  live "/", PlayerLive.Dashboard, :render
  live "/cash", PlayerLive.Dashboard, :cash_games
  live "/tournaments", PlayerLive.Dashboard, :tournaments
  live "/cash/:id/lobby", PlayerLive.Lobby, :show
  live "/tournaments/:id/lobby", PlayerLive.TournamentLobby, :show
  live "/history", PlayerLive.HandHistory, :index
end
```

- [ ] **Step 3: Add "History" sidebar link to Dashboard**

In `lib/poker_web/live/player_live/dashboard.ex`, inside the sidebar `<div class="p-5 pb-3">`, after the existing PLAY section links, add a HISTORY section. Find the line with `<div class="flex-1"></div>` and insert before it:

```elixir
<div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2 mt-4">
  HISTORY
</div>
<div class="flex flex-col gap-0.5">
  <.link
    navigate={~p"/history"}
    class="flex items-center gap-2.5 px-2.5 py-2 rounded-md text-[13px] text-[var(--pkr-ink-2)] border border-transparent hover:bg-[var(--pkr-bg-2)]/50 transition-all"
  >
    <span class="w-4 text-center text-[var(--pkr-ink-3)]">&#x2630;</span>
    <span class="flex-1">Hand history</span>
  </.link>
</div>
```

- [ ] **Step 4: Compile**

```bash
mix compile 2>&1 | grep -E "error|warning"
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/poker_web/live/player_live/hand_history.ex lib/poker_web/router.ex lib/poker_web/live/player_live/dashboard.ex
git commit -m "feat: add hand history page at /history with sidebar link"
```

---

## Task 10: End-to-end smoke test

- [ ] **Step 1: Run full test suite**

```bash
mix test
```

Expected: all tests pass with no new failures.

- [ ] **Step 2: Start server and manually verify**

```bash
mix phx.server
```

1. Log in and join a cash game table
2. Play at least one complete hand (fold to finish quickly)
3. Visit `/history` — the hand should appear in the list
4. Click "Replay" — should open the replay page showing that specific hand
5. Visit `/history?filter=cash` — should show only cash hands
6. Verify the sidebar "Hand history" link on the Dashboard navigates to `/history`

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -p
git commit -m "fix: hand history smoke test fixes"
```
