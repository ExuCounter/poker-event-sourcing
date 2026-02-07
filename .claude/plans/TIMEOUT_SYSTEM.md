# Plan: Implement Player Timeout System with Oban

## Overview
Implement automatic player timeouts using Oban job scheduling. When a player's turn timer expires, they automatically fold and are marked as sitting out. Settings are stored in the process manager state to avoid reading aggregates.

## Requirements
- Each player gets `timeout_seconds` from table settings
- On timeout: emit `ParticipantTimedOut` event → auto-fold + mark sitting out
- Modify `ParticipantToActSelected` event to include `timeout_seconds` and `started_at` (for UI countdown)
- Use Oban for reliable, persistent timeout job scheduling in `tables` queue
- Cancel timeout job if player acts before timer expires
- Store settings in process manager (no aggregate reads)

## Current State Analysis

### Event Sourcing Structure
- **Process Manager:** `/lib/poker/tables/process_manager.ex` - Orchestrates game flow
- **Turn Logic:** `/lib/poker/tables/aggregates/table/handlers/actions.ex` - Validates turns
- **Sitting Out:** Already implemented with `is_sitting_out` flag
- **Settings:** `timeout_seconds` available in `table.settings`

## Implementation Plan

### Phase 1: Modify And Add New Events

#### 1.1 Modify ParticipantToActSelected Event
**File:** `/lib/poker/tables/events/participant_to_act_selected.ex` (MODIFY FILE)

```elixir
defmodule Poker.Tables.Events.ParticipantToActSelected do
  @derive {Jason.Encoder, only: [:table_id, :round_id, :participant_id, :timeout_seconds, :started_at]}
  defstruct [:table_id, :round_id, :participant_id, :timeout_seconds, :started_at # ISO8601 timestamp]
end
```

#### 1.2 ParticipantTimedOut Event
**File:** `/lib/poker/tables/events/participant_timed_out.ex` (NEW FILE)

```elixir
defmodule Poker.Tables.Events.ParticipantTimedOut do
  @derive {Jason.Encoder, only: [
    :id,
    :table_id,
    :participant_id,
    :round_id
  ]}

  defstruct [
    :id,
    :table_id,
    :participant_id,
    :round_id
  ]
end
```

### Phase 2: Add TimeoutParticipant Command

**File:** `/lib/poker/tables/commands/timeout_participant.ex` (NEW FILE)

```elixir
defmodule Poker.Tables.Commands.TimeoutParticipant do
  use Poker, :schema

  embedded_schema do
    field :table_id, :binary_id
    field :participant_id, :binary_id
    field :round_id, :binary_id
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:table_id, :participant_id, :round_id])
    |> Ecto.Changeset.validate_required([:table_id, :participant_id, :round_id])
  end
end
```

### Phase 3: Update Aggregate Handlers

#### 3.1 Add Timeout Handler
**File:** `/lib/poker/tables/aggregates/table/handlers/actions.ex`

Add new function (similar to existing `handle` for fold/check/call):

```elixir
alias Poker.Tables.Commands.TimeoutParticipant
alias Poker.Tables.Events.{ParticipantTimedOut, ParticipantFolded, ParticipantSatOut}

def handle(%Table{hand: hand, round: round} = table, %TimeoutParticipant{} = command) do
    [
      %ParticipantTimedOut{
        table_id: command.table_id,
        participant_id: command.participant_id,
        round_id: command.round_id
      },
      %ParticipantFolded{
        id: UUID.uuid4(),
        table_id: command.table_id,
        participant_id: command.participant_id,
        table_hand_id: hand.id,
        status: :folded,
        round: round.type
      },
      %ParticipantSatOut{
        table_id: command.table_id,
        participant_id: command.participant_id
      }
    ]
end
```

#### 3.2 Add Event Handlers to Apply
**File:** `/lib/poker/tables/aggregates/table/apply/participants.ex`

Add event handler:

```elixir
alias Poker.Tables.Events.ParticipantTimedOut

def apply(%Table{} = table, %ParticipantTimedOut{} = _event) do
  # No state change needed - this is informational
  # The actual state changes come from ParticipantFolded and ParticipantSatOut
  table
end
```

### Phase 4: Fix Oban and Update Process Manager

#### 4.0 Fix Oban Configuration and Setup

**File:** `/config/config.exs` (lines 96-98)

```elixir
# Change from:
config :poker, Oban,
  repo: Pt.Repo,  # WRONG
  queues: [tables: 10]

# To:
config :poker, Oban,
  repo: Poker.Repo,
  queues: [tables: 10]
```

**File:** `/lib/poker/application.ex`

Add Oban to children list (after Poker.Repo):

```elixir
children = [
  Poker.App,
  PokerWeb.Telemetry,
  Poker.Repo,
  {Oban, Application.fetch_env!(:poker, Oban)},  # ADD THIS
  {DNSCluster, query: Application.get_env(:poker, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: Poker.PubSub},
  PokerWeb.Endpoint,
  Poker.Tables.Supervisor
]
```

#### 4.1 Create Oban Worker

**File:** `/lib/poker/workers/timeout_worker.ex` (NEW FILE)

```elixir
defmodule Poker.Workers.TimeoutWorker do
  use Oban.Worker, queue: :tables, max_attempts: 1

  alias Poker.Tables

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{
    "table_id" => table_id,
    "participant_id" => participant_id,
    "round_id" => round_id
  }}) do
    # Dispatch timeout command
    # The aggregate will validate if this is still the correct turn
    Tables.timeout_participant(%{
      table_id: table_id,
      participant_id: participant_id,
      round_id: round_id
    })

    :ok
  end
end
```

**File:** `/lib/poker/tables/process_manager.ex`

#### 4.2 Add to Interested Events

```elixir
alias Poker.Tables.Events.{
  TableCreated,
  TableStarted,
  ParticipantToActSelected,
  RoundCompleted,
  HandFinished,
  TableFinished,
  ParticipantFolded,
  ParticipantChecked,
  ParticipantCalled,
  ParticipantRaised,
  ParticipantWentAllIn
}

@impl Commanded.ProcessManagers.ProcessManager
def interested?(%TableCreated{id: table_id}), do: {:start, table_id}
def interested?(%TableStarted{id: table_id}), do: {:continue, table_id}
def interested?(%ParticipantToActSelected{table_id: table_id}), do: {:continue, table_id}
def interested?(%RoundCompleted{table_id: table_id}), do: {:continue, table_id}
def interested?(%HandFinished{table_id: table_id}), do: {:continue, table_id}
def interested?(%TableFinished{id: table_id}), do: {:stop, table_id}
# Player actions to cancel timeout
def interested?(%ParticipantFolded{table_id: table_id}), do: {:continue, table_id}
def interested?(%ParticipantChecked{table_id: table_id}), do: {:continue, table_id}
def interested?(%ParticipantCalled{table_id: table_id}), do: {:continue, table_id}
def interested?(%ParticipantRaised{table_id: table_id}), do: {:continue, table_id}
def interested?(%ParticipantWentAllIn{table_id: table_id}), do: {:continue, table_id}
def interested?(_event), do: false
```

#### 4.3 Update State Structure

```elixir
defstruct [
  :table_id,
  :timeout_seconds,           # Store from TableCreated
  :current_timeout_job_id     # Track Oban job ID for cancellation
]
```

#### 4.4 Apply TableCreated - Store Settings

```elixir
# Store table settings when table is created
def apply(%ProcessManager{} = pm, %TableCreated{settings: settings} = event) do
  %{pm |
    table_id: event.id,
    timeout_seconds: settings.timeout_seconds
  }
end
```

#### 4.5 Apply ParticipantToActSelected - Schedule Oban Job

```elixir
alias Poker.Workers.TimeoutWorker

# When ParticipantToActSelected event is applied, schedule Oban job
def apply(%ProcessManager{timeout_seconds: timeout_seconds} = pm, %ParticipantToActSelected{} = event) do
  # Cancel any existing timeout job
  if pm.current_timeout_job_id do
    Oban.cancel_job(pm.current_timeout_job_id)
  end

  # Schedule timeout job in tables queue
  {:ok, job} = %{
    table_id: event.table_id,
    participant_id: event.participant_id,
    round_id: event.round_id
  }
  |> TimeoutWorker.new(schedule_in: timeout_seconds, queue: :tables)
  |> Oban.insert()

  %{pm | current_timeout_job_id: job.id}
end
```

#### 4.6 Apply Player Actions - Cancel Oban Job

```elixir
# When participant acts (fold/check/call/raise/all_in), cancel timeout
def apply(%ProcessManager{current_timeout_job_id: job_id} = pm, event)
    when event.__struct__ in [
      ParticipantFolded,
      ParticipantChecked,
      ParticipantCalled,
      ParticipantRaised,
      ParticipantWentAllIn
    ] do

  # Cancel the scheduled timeout job
  if job_id do
    Oban.cancel_job(job_id)
  end

  %{pm | current_timeout_job_id: nil}
end
```

### Phase 5: Update Turn Selection Logic

**File:** `/lib/poker/tables/aggregates/table/helpers.ex`

Update `find_next_participant_to_act` to exclude sitting out players:

```elixir
defp find_next_active_participant(participants, start_index) do
  total = length(participants)
  indices = for offset <- 1..total, do: rem(start_index + offset, total)

  Enum.find_value(indices, fn index ->
    participant = Enum.at(participants, index)

    # Active means: status == :active AND chips > 0 AND NOT sitting out
    if participant.status == :active and
       participant.chips > 0 and
       not participant.is_sitting_out do
      participant
    end
  end)
end
```

### Phase 6: Add Context API Function

**File:** `/lib/poker/tables.ex`

Add public function for timeout command:

```elixir
alias Poker.Tables.Commands.TimeoutParticipant

def timeout_participant(attrs) do
  with {:ok, command} <- validate_command(TimeoutParticipant, attrs) do
    Poker.App.dispatch(command, consistency: :strong)
  end
end
```

### Phase 7: Update GameStateBuilder for UI

**File:** `/lib/poker/tables/views/game_state_builder.ex`

Add timeout information to game state:

```elixir
def build(table) do
  %{
    # ... existing fields ...
    timeout_seconds: table.settings.timeout_seconds,
    current_turn: %{
      participant_id: table.round.participant_to_act_id,
      # UI will need to track when turn started from ParticipantTurnStarted event
    }
  }
end
```

## Data Flow

```
Table Created
    ↓
ProcessManager receives TableCreated
    ↓
Apply TableCreated → Store timeout_seconds in PM state
    ↓
    ...
    ↓
Turn Starts (ParticipantToActSelected event emitted)
    ↓
ProcessManager applies ParticipantToActSelected
    ↓
├─> Schedule Oban job (timeout_seconds delay, tables queue)
└─> Store job_id in PM state
    ↓
    ├─ CASE 1: Player acts in time
    │     ↓
    │  ProcessManager applies action event (fold/check/call/raise)
    │     ↓
    │  Cancel Oban job with Oban.cancel_job(job_id)
    │     ↓
    │  Clear job_id from PM state
    │     ↓
    │  Continue game normally
    │
    └─ CASE 2: Timer expires
          ↓
       Oban executes TimeoutWorker
          ↓
       Dispatch TimeoutParticipant command
          ↓
       Aggregate validates (still correct turn?)
          ↓
       Emit: ParticipantTimedOut + ParticipantFolded + ParticipantSatOut
          ↓
       UI updates (player folded + marked sitting out)
          ↓
       Game continues to next player
```

## Files to Create/Modify

### New Files
1. `/lib/poker/workers/timeout_worker.ex` - Oban worker
2. `/lib/poker/tables/events/participant_timed_out.ex` - Timeout event
3. `/lib/poker/tables/commands/timeout_participant.ex` - Timeout command

### Modified Files
1. `/config/config.exs` - Fix Oban repo config
2. `/lib/poker/application.ex` - Add Oban to supervision tree
3. `/lib/poker/tables/events/participant_to_act_selected.ex` - Participant selected event (add timeout_seconds and started_at)
4. `/lib/poker/tables/process_manager.ex` - Schedule/cancel Oban jobs, store settings from TableCreated
5. `/lib/poker/tables/aggregates/table/handlers/actions.ex` - Handle TimeoutParticipant
6. `/lib/poker/tables/aggregates/table/apply/participants.ex` - Apply ParticipantTimedOut
7. `/lib/poker/tables/aggregates/table/helpers.ex` - Skip sitting out players
8. `/lib/poker/tables.ex` - Add timeout_participant/1 function
9. `/lib/poker/tables/views/game_state_builder.ex` - Add timeout info

## Testing Checklist

1. **Oban Setup**
   - [ ] Oban starts without errors
   - [ ] Jobs can be scheduled and executed
   - [ ] Tables queue processes jobs

2. **Happy Path**
   - [ ] Player acts before timeout → job cancelled, game continues
   - [ ] Turn countdown displays correctly in UI (from ParticipantToActSelected event)

3. **Timeout Path**
   - [ ] Timer expires → ParticipantTimedOut emitted
   - [ ] Player automatically folds
   - [ ] Player marked as sitting out
   - [ ] Game continues to next active player

4. **Edge Cases**
   - [ ] Sitting out players are skipped in turn selection
   - [ ] Player can manually sit back in
   - [ ] All players sitting out → hand ends appropriately
   - [ ] Multiple tables timeout independently
   - [ ] Job cancellation works correctly

## Notes

- **Why Oban?** Persistent, reliable, survives app restarts, handles concurrent timeouts across tables
- **Why max_attempts: 1?** Time-sensitive, no retry needed
- **Why store settings in PM?** Avoids reading aggregate, settings available immediately from TableCreated event
- **Why three events?** Separation of concerns - timeout is different from fold, fold is different from sitting out
- **Process Manager state:** Track timeout_seconds (from TableCreated) + current_timeout_job_id (for cancellation)
- **Validation safety:** Aggregate validates round_id/turn - stale timeouts are automatically rejected
- **Queue:** Uses dedicated `tables` queue with 10 workers for isolation from other background jobs
