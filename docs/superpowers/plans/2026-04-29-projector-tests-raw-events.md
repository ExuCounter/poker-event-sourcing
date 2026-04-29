# Projector Tests: Raw Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SeedFactory-based projector tests with direct `handle/2` calls using hand-constructed event structs.

**Architecture:** Each test constructs raw event structs and calls the projector's `handle/2` function directly. This bypasses commands, aggregates, event store, and deck fixtures. SeedFactory is only used for creating user records where the projector needs them (TableLobby's `ParticipantJoined`).

**Tech Stack:** Elixir, ExUnit, Commanded.Projections.Ecto (`handle/2`), SeedFactory (user creation only)

---

### Task 1: Rewrite TableListTest with raw events

**Files:**
- Modify: `test/poker/tables/projectors/table_list_test.exs`

- [ ] **Step 1: Rewrite the full test file**

Replace the entire file contents with:

```elixir
defmodule Poker.Tables.Projectors.TableListTest do
  use Poker.DataCase

  alias Poker.Tables.Projectors.TableList, as: Projector
  alias Poker.Tables.Projections.TableList

  alias Poker.Tables.Events.{
    TableCreated,
    TableStarted,
    ParticipantJoined,
    ParticipantBusted,
    TableFinished,
    TablePaused,
    TableResumed
  }

  setup do
    Poker.Tables.PubSub.subscribe_to_table_list()
    on_exit(fn -> Poker.Tables.PubSub.unsubscribe_from_table_list() end)
  end

  defp create_table(opts \\ %{}) do
    table_id = opts[:table_id] || Ecto.UUID.generate()

    event = %TableCreated{
      id: table_id,
      status: :waiting,
      table_type: opts[:table_type] || :six_max,
      game_mode: opts[:game_mode] || :tournament,
      source_id: opts[:source_id] || Ecto.UUID.generate()
    }

    :ok = Projector.handle(event, %{})
    table_id
  end

  defp join_participant(table_id, opts \\ %{}) do
    participant_id = opts[:participant_id] || Ecto.UUID.generate()

    event = %ParticipantJoined{
      id: participant_id,
      table_id: table_id,
      player_id: opts[:player_id] || Ecto.UUID.generate(),
      seat_number: opts[:seat_number] || 1
    }

    :ok = Projector.handle(event, %{})
    participant_id
  end

  describe "TableCreated event" do
    test "creates a new table list entry with correct initial values" do
      table_id = create_table()

      assert_receive {:table_list, :table_created, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.id == table_id
      assert table.status == :waiting
      assert table.seated_count == 0
      assert table.seats_count == 6
    end
  end

  describe "TableStarted event" do
    test "updates table status to live" do
      table_id = create_table(table_type: :three_max)
      join_participant(table_id, seat_number: 1)
      join_participant(table_id, seat_number: 2)
      join_participant(table_id, seat_number: 3)

      :ok = Projector.handle(%TableStarted{id: table_id, status: :live}, %{})

      assert_receive {:table_list, :table_started, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :live
      assert table.seated_count == 3
    end
  end

  describe "ParticipantJoined event" do
    test "increments seated count" do
      table_id = create_table()
      participant_id = join_participant(table_id)

      assert_receive {:table_list, :participant_joined, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableList, table_id)

      assert table.seated_count == 1
    end
  end

  describe "ParticipantBusted event" do
    test "decrements seated count" do
      table_id = create_table(table_type: :three_max)
      participant_id_1 = join_participant(table_id, seat_number: 1)
      join_participant(table_id, seat_number: 2)
      join_participant(table_id, seat_number: 3)

      :ok = Projector.handle(%ParticipantBusted{table_id: table_id, participant_id: participant_id_1, player_id: Ecto.UUID.generate()}, %{})

      assert_receive {:table_list, :participant_busted, %{table_id: ^table_id, participant_id: ^participant_id_1}}

      table = Repo.get(TableList, table_id)

      assert table.seated_count == 2
    end
  end

  describe "TableFinished event" do
    test "updates table status to finished" do
      table_id = create_table()

      :ok = Projector.handle(%TableFinished{table_id: table_id}, %{})

      assert_receive {:table_list, :table_finished, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :finished
    end
  end

  describe "TablePaused event" do
    test "updates table status to paused" do
      table_id = create_table()

      :ok = Projector.handle(%TablePaused{table_id: table_id}, %{})

      assert_receive {:table_list, :table_paused, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :paused
    end
  end

  describe "TableResumed event" do
    test "updates table status to live" do
      table_id = create_table()
      :ok = Projector.handle(%TablePaused{table_id: table_id}, %{})

      :ok = Projector.handle(%TableResumed{table_id: table_id}, %{})

      assert_receive {:table_list, :table_resumed, %{table_id: ^table_id}}

      table = Repo.get(TableList, table_id)

      assert table.status == :live
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test test/poker/tables/projectors/table_list_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/poker/tables/projectors/table_list_test.exs
git commit -m "refactor: rewrite TableListTest to use raw events via handle/2"
```

---

### Task 2: Rewrite TableLobbyTest with raw events

**Files:**
- Modify: `test/poker/tables/projectors/table_lobby_test.exs`

- [ ] **Step 1: Rewrite the full test file**

Replace the entire file contents with:

```elixir
defmodule Poker.Tables.Projectors.TableLobbyTest do
  use Poker.DataCase

  alias Poker.Tables.Projectors.TableLobby, as: Projector
  alias Poker.Tables.Projections.TableLobby

  alias Poker.Tables.Events.{
    TableCreated,
    TableStarted,
    ParticipantJoined,
    ParticipantBusted,
    ParticipantLeft,
    TableFinished,
    TablePaused,
    TableResumed
  }

  defp create_table(opts \\ %{}) do
    table_id = opts[:table_id] || Ecto.UUID.generate()

    event = %TableCreated{
      id: table_id,
      status: :waiting,
      table_type: opts[:table_type] || :six_max,
      small_blind: opts[:small_blind] || 10,
      big_blind: opts[:big_blind] || 20,
      starting_stack: opts[:starting_stack] || 1000,
      creator_id: opts[:creator_id] || Ecto.UUID.generate()
    }

    :ok = Projector.handle(event, %{})
    table_id
  end

  defp create_user(ctx) do
    ctx |> produce(:player, traits: [:active])
  end

  defp join_participant(table_id, player, opts \\ %{}) do
    participant_id = opts[:participant_id] || Ecto.UUID.generate()

    event = %ParticipantJoined{
      id: participant_id,
      table_id: table_id,
      player_id: player.id,
      seat_number: opts[:seat_number] || 1
    }

    :ok = Projector.handle(event, %{})
    participant_id
  end

  describe "TableCreated event" do
    test "creates a new table lobby entry" do
      table_id = create_table(small_blind: 10, big_blind: 20, starting_stack: 1000, table_type: :six_max)

      table = Repo.get(TableLobby, table_id)

      assert table.status == :waiting
      assert table.small_blind == 10
      assert table.big_blind == 20
      assert table.starting_stack == 1000
      assert table.table_type == :six_max
      assert table.seated_count == 0
      assert table.seats_count == 6
      assert table.participants == []
    end
  end

  describe "ParticipantJoined event" do
    test "adds participant to lobby and increments seated count", ctx do
      table_id = create_table(table_type: :two_max)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      ctx = create_user(ctx)
      participant_id = join_participant(table_id, ctx.player, seat_number: 1)

      assert_receive {:table_lobby, :participant_joined, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.seated_count == 1
      assert length(table.participants) == 1

      participant = hd(table.participants)
      assert participant.player_id == ctx.player.id
      assert participant.email == ctx.player.email
      assert participant.nickname == ctx.player.nickname
      assert participant.seat_number == 1
    end
  end

  describe "TableStarted event" do
    test "updates table status to live", ctx do
      table_id = create_table(table_type: :three_max)

      ctx = create_user(ctx)
      join_participant(table_id, ctx.player, seat_number: 1)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TableStarted{id: table_id, status: :live}, %{})

      assert_receive {:table_lobby, :table_started, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :live
    end
  end

  describe "ParticipantBusted event" do
    test "marks participant as busted and decrements seated count", ctx do
      table_id = create_table(table_type: :two_max)

      ctx = create_user(ctx)
      participant_id = join_participant(table_id, ctx.player, seat_number: 1)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%ParticipantBusted{table_id: table_id, participant_id: participant_id, player_id: ctx.player.id}, %{})

      assert_receive {:table_lobby, :participant_busted, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.seated_count == 0
      assert length(table.participants) == 1
      assert hd(table.participants).status == :busted
    end
  end

  describe "ParticipantLeft event" do
    test "removes participant from list and decrements seated count", ctx do
      table_id = create_table(table_type: :two_max)

      ctx = create_user(ctx)
      participant_id = join_participant(table_id, ctx.player, seat_number: 1)

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%ParticipantLeft{table_id: table_id, participant_id: participant_id, player_id: ctx.player.id}, %{})

      assert_receive {:table_lobby, :participant_left, %{table_id: ^table_id, participant_id: ^participant_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.seated_count == 0
      assert table.participants == []
    end
  end

  describe "TableFinished event" do
    test "updates table status to finished" do
      table_id = create_table()

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TableFinished{table_id: table_id}, %{})

      assert_receive {:table_lobby, :table_finished, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :finished
    end
  end

  describe "TablePaused event" do
    test "updates table status to paused" do
      table_id = create_table()

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TablePaused{table_id: table_id}, %{})

      assert_receive {:table_lobby, :table_paused, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :paused
    end
  end

  describe "TableResumed event" do
    test "updates table status to live" do
      table_id = create_table()
      :ok = Projector.handle(%TablePaused{table_id: table_id}, %{})

      Poker.Tables.PubSub.subscribe_to_lobby(table_id)

      :ok = Projector.handle(%TableResumed{table_id: table_id}, %{})

      assert_receive {:table_lobby, :table_resumed, %{table_id: ^table_id}}

      table = Repo.get(TableLobby, table_id)

      assert table.status == :live
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test test/poker/tables/projectors/table_lobby_test.exs`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/poker/tables/projectors/table_lobby_test.exs
git commit -m "refactor: rewrite TableLobbyTest to use raw events via handle/2"
```

---

### Task 3: Run full test suite

- [ ] **Step 1: Run all tests to verify nothing is broken**

Run: `mix test`
Expected: All tests pass. No regressions.

- [ ] **Step 2: Commit the spec update (if not already committed)**

```bash
git add docs/superpowers/specs/2026-04-29-projector-tests-raw-events-design.md
git commit -m "docs: update spec with SeedFactory for user creation"
```
