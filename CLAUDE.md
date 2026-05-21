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

## Contexts

### Accounts (`/accounts`)

Standard CRUD context: Users, Tokens, authentication emails.

### Tables (`/tables`)

Event Sourced context managing poker table logic.

## Specialized Agents

For domain-specific work, use the appropriate subagent:

- **`event-sourcing-builder`** — aggregates, commands, events, projections, projectors, command dispatch
- **`liveview-builder`** — LiveViews, HEEx templates, forms, streams, router placement, LiveView tests
- **`ui-designer`** — styling, Tailwind v4, components, JS/CSS assets, design polish

## Project Guidelines

- Use `mix precommit` alias when done with all changes and fix any pending issues
- Use the already included `:req` (`Req`) library for HTTP requests — **avoid** `:httpoison`, `:tesla`, and `:httpc`

## Authentication

Authentication is provided by `phx.gen.auth`. Key concepts all agents must know:

- `@current_scope` is assigned on every connection and socket — **never** use `@current_player`
- Access the player as `@current_scope.player` in templates and `scope.player` in context calls
- Always pass `current_scope` as the first argument to context functions
- Two `live_session` scopes exist in the router: `:require_authenticated_player` (login required) and `:current_player` (optional auth) — see `liveview-builder` for placement details

## Elixir Guidelines

- Lists **do not support index-based access** — use `Enum.at/2`, pattern matching, or `List` functions
- Block expressions (`if`, `case`, `cond`) must have their result bound outside the block:

      # INVALID
      if condition do
        socket = assign(socket, :val, val)
      end

      # VALID
      socket = if condition do
        assign(socket, :val, val)
      end

- **Never** nest multiple modules in the same file — causes cyclic dependencies
- **Never** use map access syntax (`changeset[:field]`) on structs — access fields directly or use `Ecto.Changeset.get_field/2`
- **Never** use `String.to_atom/1` on user input — memory leak risk
- Predicate function names must end in `?`, not start with `is_` (reserve `is_thing` for guards)
- Use `Task.async_stream(collection, callback, timeout: :infinity)` for concurrent enumeration with back-pressure
- OTP primitives (`DynamicSupervisor`, `Registry`) require a `:name` in the child spec
- Elixir has no `else if` — use `cond` or `case` for multiple branches

## Mix Guidelines

- Read docs before using tasks: `mix help task_name`
- Debug failures: `mix test test/my_test.exs` or `mix test --failed`
- Avoid `mix deps.clean --all` unless you have a specific reason

## Phoenix Guidelines

- Router `scope` blocks prefix an alias to all routes within — never add your own `alias` for route definitions
- `Phoenix.View` is no longer included — don't use it

## Ecto Guidelines

- Always preload associations in queries when they'll be accessed in templates
- `Ecto.Schema` fields always use `:string` type, even for `:text` columns
- `validate_number/2` does not support `:allow_nil` — it is never needed
- Use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Never list programmatically-set fields (e.g. `user_id`) in `cast` — set them explicitly on the struct

## Phoenix HTML

- Always use `~H` or `.html.heex` files — never `~E`
- Always use `Phoenix.Component.form/1` and `to_form/2` — never the old `Phoenix.HTML.form_for`

# Repository Guidelines

## AI Assistant Integration

This project uses [Tidewave MCP](https://hexdocs.pm/tidewave) for enhanced Elixir/Phoenix development. Prefer Tidewave tools over generic file operations:

- **`mcp__tidewave__project_eval`** — evaluate Elixir code in project context
- **`mcp__tidewave__get_docs`** — access module/function documentation
- **`mcp__tidewave__get_source_location`** — find where modules or functions are defined
- **`mcp__tidewave__get_ecto_schemas`** — list all Ecto schemas
- **`mcp__tidewave__execute_sql_query`** — query the database directly
- **`mcp__tidewave__search_package_docs`** — search across dependency docs
- **`mcp__tidewave__get_logs`** — check application logs

Use these instead of: grep/search (`get_source_location`), reading docs (`get_docs`), IEx (`project_eval`), psql (`execute_sql_query`).

## Build, Test, and Development Commands

Bootstrap with `mise install` then `mix deps.get`. Use `mix ecto.setup` for a fresh database and `mix ecto.migrate` after schema changes. Start with `iex -S mix phx.server`. Run tests with `mix test`; narrow scope with `mix test apps/pt/test/<file>`. Style: `mix format` and `mix credo --strict`.

## Coding Style

Keep code formatter-clean (120-character width). Prefer explicit module names (`Poker.Accounts`). Files snake_case, modules PascalCase. Refactor long pipelines into `with` blocks or private helpers.

## Testing Guidelines

ExUnit suites beside code as `*_test.exs` with descriptive `describe` blocks. Use factories from `test/support`. Mock external services with Mox or Hammox. CI artifacts: `mix test --formatter JunitFormatter`.

## Commit & Pull Request Guidelines

Use the `/commit` skill to stage and commit changes. Keep schema updates and matching seeds together.
