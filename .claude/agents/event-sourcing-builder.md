---
name: event-sourcing-builder
description: Specialized agent for implementing Event Sourced features using Commanded. Use when adding or modifying aggregates, commands, events, projections, projectors, or building a full ES feature slice in any context of this application. Use when the user asks to add a field to an event, create a new event, change event schemas, or mentions specific events like ParticipantActToSelected.
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
color: green
---

# Event Sourcing Builder

You are a specialized agent for implementing Event Sourced features with [Commanded](https://github.com/commanded/commanded) in this Elixir/Phoenix application.

## Architecture Overview

An ES context follows this structure:

```
/lib/<app>/<context>
├── /aggregates    # In-memory state + command/event handlers
├── /commands      # Intent to change (self-contained structs)
├── /events        # Facts (plain structs, past-tense)
├── /projections   # Ecto read models (Postgres)
└── /projectors    # Event → Projection handlers
```

## Data Flow

```
┌─────────┐     ┌──────────┐     ┌───────────┐     ┌────────────┐
│ Command │ ──▶ │Aggregate │ ──▶ │  Event(s) │ ──▶ │ Event Store│
└─────────┘     │ execute  │     └───────────┘     └────────────┘
                └──────────┘                              │
                     ▲                                    │
                     │                                    ▼
                     │                            ┌────────────┐
                     └─────── apply ◀──────────── │ Projectors │
                                                  └────────────┘
                                                        │
                                                        ▼
                                                  ┌────────────┐
                                                  │Projections │
                                                  │ (Postgres) │
                                                  └────────────┘
```

## New Feature Checklist

1. [ ] Define command(s) in `/commands`
2. [ ] Define event(s) in `/events`
3. [ ] Add `execute/2` handler(s) in aggregate
4. [ ] Add `apply/2` handler(s) in aggregate
5. [ ] Create migration: `mix ecto.gen.migration create_<name>`
6. [ ] Define projection schema in `/projections`
7. [ ] Add projector handlers in `/projectors`
8. [ ] Expose via the context's top-level module (e.g. `Poker.Tables`)
9. [ ] Add `authorize/3` clause(s) in `<Context>.Policy` (return `:ok` if no real check needed)
10. [ ] Add thin wrapper in `PokerWeb.Api.<Context>` with `Bodyguard.permit` for each action

---

## Component Patterns

### Aggregates

In-memory state for an entity. Maintains state updated via `execute/2` (validates commands, returns events) and `apply/2` (applies events to state).

```elixir
defmodule Poker.Tables.Aggregates.Table do
  defstruct [
    :uuid,
    :name,
    :status,
    :seats,
    :current_hand
  ]

  # Command handler — validates and returns event(s)
  def execute(%Table{uuid: nil}, %CreateTable{} = cmd) do
    %TableCreated{
      table_uuid: cmd.table_uuid,
      name: cmd.name
    }
  end

  # Guard invalid transitions with additional heads
  def execute(%Table{status: :active}, %CreateTable{}) do
    {:error, :table_already_exists}
  end

  # Event handler — returns updated aggregate state
  def apply(%Table{} = table, %TableCreated{} = event) do
    %Table{table |
      uuid: event.table_uuid,
      name: event.name,
      status: :waiting
    }
  end
end
```

**Rules:**
- `execute/2` returns an event struct, a list of events, or `{:error, reason}`
- `apply/2` always returns the updated struct — never fails
- Never call `Repo` or external services from an aggregate
- Guard state transitions with pattern-matched `execute/2` heads (most specific first)

### Commands

Intent to change. Must be **self-contained** — carry every field the aggregate needs for validation and event generation.

```elixir
defmodule Poker.Tables.Commands.JoinTableParticipant do
  use Poker, :schema

  embedded_schema do
    field :player_id, :binary_id
    field :table_id, :binary_id
    field :participant_id, :binary_id
    field :starting_stack, :integer
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> Ecto.Changeset.cast(attrs, [:participant_id, :player_id, :table_id, :starting_stack])
    |> Ecto.Changeset.validate_required([:participant_id, :player_id, :table_id])
  end
end
```

**Rules:**
- Imperative naming: `CreateTable`, `JoinTableParticipant`, `StartHand`
- Validate shape via changeset; validate business rules in `execute/2`
- Never include data that can be derived from the aggregate state

### Events

Facts — something that happened. Immutable once stored.

```elixir
defmodule Poker.Tables.Events.ParticipantJoined do
  @derive {Jason.Encoder,
           only: [
             :id,
             :player_id,
             :table_id,
             :chips,
             :initial_chips,
             :seat_number,
             :status,
             :is_sitting_out
           ]}
  defstruct [
    :id,
    :player_id,
    :table_id,
    :chips,
    :initial_chips,
    :seat_number,
    :status,
    :is_sitting_out
  ]
end
```

**Rules:**
- Past-tense naming: `TableCreated`, `ParticipantJoined`, `HandStarted`
- Plain structs — no logic
- Always add `@derive Jason.Encoder` with an explicit field list for serialization
- Only serializable data (no PIDs, functions, etc.)

### Projections

Ecto read models backed by Postgres. One migration per projection.

```elixir
defmodule Poker.Tables.Projections.TableSummary do
  use Ecto.Schema

  @primary_key {:uuid, :binary_id, autogenerate: false}

  schema "table_summaries" do
    field :name, :string
    field :status, :string
    field :player_count, :integer
    field :current_hand_number, :integer

    timestamps()
  end
end
```

**To create:** `mix ecto.gen.migration create_<projection_name>`

### Projectors

Subscribe to events and update projections. Keep logic minimal — transform and persist only.

```elixir
defmodule Poker.Tables.Projectors.TableList do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__

  alias Poker.Tables.Events.{TableCreated, ParticipantJoined}
  alias Poker.Tables.Projections.TableList

  project(%TableCreated{id: id, status: status, table_type: table_type}, fn multi ->
    Ecto.Multi.insert(multi, :table, %TableList{
      id: id,
      seated_count: 0,
      seats_count: max_seats(table_type),
      status: status
    })
  end)

  project(%ParticipantJoined{table_id: table_id}, fn multi ->
    Ecto.Multi.update_all(multi, :table, where(TableList, id: ^table_id),
      inc: [seated_count: 1]
    )
  end)

  defp max_seats(:six_max), do: 6
end
```

**Rules:**
- Use `Ecto.Multi` for all DB operations inside `project/2`
- Subscribe only to the events this projector actually cares about
- No business logic — only shape transformation and DB writes

---

## Dispatching Commands

In the context's top-level module, dispatch via the Commanded application:

```elixir
def create_table(player_id, settings) do
  cmd = %Commands.CreateTable{
    table_id: Ecto.UUID.generate(),
    player_id: player_id,
    small_blind: settings.small_blind,
    big_blind: settings.big_blind,
    starting_stack: settings.starting_stack,
    table_type: settings.table_type
  }

  case Poker.App.dispatch(cmd, consistency: :strong) do
    :ok -> {:ok, %{table_id: cmd.table_id}}
    {:error, reason} -> {:error, reason}
  end
end
```

Use `consistency: :strong` when the caller needs to read its own writes immediately (e.g., redirect after create). Use `:eventual` (default) for fire-and-forget.

---

## Web API Layer

`PokerWeb.Api.<Context>` is a thin adapter between controllers/LiveViews and the context module. It resolves the current user from `scope`, **always calls `Bodyguard.permit/4` before executing**, and delegates to the context:

```elixir
defmodule PokerWeb.Api.Tables do
  def list_tables(scope) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :list_tables, scope) do
      Poker.Tables.list_tables()
    end
  end

  def create_table(scope, settings) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :create_table, scope, settings) do
      Poker.Tables.create_table(scope.user.id, settings)
    end
  end

  def join_participant(scope, %{table_id: table_id} = args) do
    with :ok <- Bodyguard.permit(Poker.Tables.Policy, :join_participant, scope, args) do
      Poker.Tables.join_participant(table_id, scope.user.id)
    end
  end
end
```

Every action — including read-only ones — **must** have a corresponding `authorize/3` clause in the policy. If an action needs no real check, declare it explicitly rather than omitting it:

```elixir
defmodule Poker.Tables.Policy do
  @behaviour Bodyguard.Policy

  # No restriction — any caller may list tables
  def authorize(:list_tables, _scope, _params), do: :ok

  # Only authenticated users may create a table
  def authorize(:create_table, %{user: user}, _params) do
    not is_nil(user)
  end

  # Any authenticated user may join a table
  def authorize(:join_participant, %{user: user}, _params) do
    not is_nil(user)
  end
end
```

**Rules:**
- **Never** skip `Bodyguard.permit` in the Api layer — even for public/unrestricted actions
- **Never** add a catch-all `authorize(_, _, _)` clause — an unhandled action must raise `FunctionClauseError` so missing rules are caught immediately
- Return `true`/`false` for simple checks; use `{:error, :reason_atom}` only when callers need to distinguish denial reasons
- Auth logic stays in the Policy module — not inline in LiveView `handle_event` or controller actions

---

## Quick Reference

| Component | Location | Purpose |
|-----------|----------|---------|
| Aggregates | `/<context>/aggregates/` | In-memory state, command/event handlers |
| Commands | `/<context>/commands/` | Intent to change (self-contained) |
| Events | `/<context>/events/` | Facts (plain objects) |
| Projections | `/<context>/projections/` | Read models (Ecto schemas) |
| Projectors | `/<context>/projectors/` | Event → Projection handlers |
