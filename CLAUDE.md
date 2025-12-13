# Poker Application Architecture

## Overview

This is an Elixir/Phoenix application using Event Sourcing (ES) for the core poker table logic. The main business logic resides in `/lib/poker`.

## Directory Structure

```
/lib/poker
├── /accounts          # CRUD context - Users, Roles, Authentication
└── /tables            # Event Sourced context - Poker table logic
    ├── /aggregates
    ├── /commands
    ├── /events
    ├── /projections
    └── /projectors
```

---

## Contexts

### Accounts (`/accounts`)

Standard CRUD context handling:

- **Users** - User records and profile data
- **Tokens** - Authentication tokens (sessions, API keys, password reset, etc.)
- Sending authentication emails to a users

### Tables (`/tables`)

Event Sourced context managing poker table logic.

---

## Event Sourcing Components

### Aggregates

In-memory state for entities. Each aggregate maintains state updated via command and event handlers.

| Function | Purpose |
|----------|---------|
| `execute/2` | Command handler - validates and returns events |
| `apply/2` | Event handler - updates aggregate state |

**Example structure:**

```elixir
defmodule Poker.Tables.Aggregates.Table do
  defstruct [
    :uuid,
    :name,
    :status,
    :seats,
    :current_hand,
    # ...
  ]

  # Command handlers
  def execute(%Table{uuid: nil}, %CreateTable{} = cmd) do
    # Validate and return event(s)
    %TableCreated{
      table_uuid: cmd.table_uuid,
      name: cmd.name
    }
  end

  # Event handlers
  def apply(%Table{} = table, %TableCreated{} = event) do
    %Table{table |
      uuid: event.table_uuid,
      name: event.name,
      status: :waiting
    }
  end
end
```

### Commands

Intent to make a change in the aggregate. Commands must be **self-contained** with all necessary information included.

**Guidelines:**

- Include all data needed for execution
- Use meaningful field names
- Validate at the aggregate level

**Example:**

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

### Events

Facts representing something that happened in the system. Events should be **plain objects** (simple data structures).

**Guidelines:**

- Past tense naming (`TableCreated`, `PlayerJoined`)
- Immutable once stored
- Contain only serializable data

**Example:**

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

### Projections

Readable models using Ecto schemas. Currently backed by PostgreSQL.

**To add a new projection:**

```bash
mix ecto.gen.migration create_<projection_name>
```

**Example:**

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

### Projectors

Event handlers for projections. Handle only related events with minimal structure.

**Guidelines:**

- Subscribe only to relevant events
- Keep logic minimal - transform and persist
- Use `Ecto.Multi` for transactional updates when needed

**Example:**

```elixir
defmodule Poker.Tables.Projectors.TableList do
  use Commanded.Projections.Ecto,
    application: Poker.App,
    repo: Poker.Repo,
    name: __MODULE__

  alias Poker.Tables.Events.{
    TableCreated
  }

  alias Poker.Tables.Projections.TableList

  def max_seats(:six_max), do: 6

  project(%TableCreated{id: id, status: status, table_type: table_type}, fn multi ->
    seats_count = max_seats(table_type)

    Ecto.Multi.insert(multi, :table, %TableList{
      id: id,
      seated_count: 0,
      seats_count: seats_count,
      status: status
    })
  end)
end
```

---

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

---

## Quick Reference

| Component | Location | Purpose |
|-----------|----------|---------|
| Aggregates | `/tables/aggregates/` | In-memory state, command/event handlers |
| Commands | `/tables/commands/` | Intent to change (self-contained) |
| Events | `/tables/events/` | Facts (plain objects) |
| Projections | `/tables/projections/` | Read models (Ecto schemas) |
| Projectors | `/tables/projectors/` | Event → Projection handlers |

---


## Web API Layer
The PokerWeb.Api module acts as a thin interface between Phoenix controllers/LiveViews and the business logic contexts.

```
/lib/poker_web
└── /api
    └── tables.ex
```

### Pattern

```
defmodule PokerWeb.Api.Tables do
  # Public queries (no scope required)
  def list_tables do
    Poker.Tables.list_tables()
  end

  def get_lobby(table_id) do
    Poker.Tables.get_lobby(table_id)
  end

  # Scoped actions (require authenticated user)
  def create_table(%{user: user} = _scope, settings) do
    Poker.Tables.create_table(user.id, settings)
  end

  def join_participant(%{user: user} = _scope, %{table_id: table_id}) do
    Poker.Tables.join_participant(table_id, user.id)
  end
end
```

### Scope

The `scope` map contains the current user context, typically assigned in the connection/socket:

```
%{user: %User{id: "...", ...}}
```

## Usage in controllers

```
defmodule PokerWeb.TableController do
  use PokerWeb, :controller
  require Logger

  def create(conn, _params) do
    case PokerWeb.Api.Tables.create_table(conn.assigns.current_scope, %{
           small_blind: 10,
           big_blind: 20,
           starting_stack: 1000,
           timeout_seconds: 90,
           table_type: :six_max
         }) do
      {:ok, %{table_id: table_id}} ->
        redirect(conn, to: ~p"/tables/#{table_id}/lobby")

      {:error, %{message: message} = reason} ->
        Logger.error("Failed to create table: #{inspect(reason)}")

        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/")
    end
  end
end
```

## Adding New Features Checklist

1. [ ] Define command(s) in `/commands`
2. [ ] Define event(s) in `/events`
3. [ ] Add `execute/2` handler(s) in aggregate
4. [ ] Add `apply/2` handler(s) in aggregate
5. [ ] Create migration: `mix ecto.gen.migration ...`
6. [ ] Define projection schema in `/projections`
7. [ ] Add projector handlers in `/projectors`
