defmodule Poker.SagaTest do
  use ExUnit.Case, async: true

  alias Poker.Saga

  describe "compensate/2" do
    test "compensates all steps before the failed step in reverse order" do
      log = Agent.start_link(fn -> [] end) |> elem(1)

      compensations = [
        {:step_a, fn -> Agent.update(log, &[{:compensated, :step_a} | &1]) end},
        {:step_b, fn -> Agent.update(log, &[{:compensated, :step_b} | &1]) end},
        {:step_c, fn -> Agent.update(log, &[{:compensated, :step_c} | &1]) end}
      ]

      Saga.compensate(:step_c, compensations)

      assert Agent.get(log, & &1) == [{:compensated, :step_a}, {:compensated, :step_b}]
    end

    test "compensates nothing when the first step fails" do
      log = Agent.start_link(fn -> [] end) |> elem(1)

      compensations = [
        {:step_a, fn -> Agent.update(log, &[{:compensated, :step_a} | &1]) end},
        {:step_b, fn -> Agent.update(log, &[{:compensated, :step_b} | &1]) end}
      ]

      Saga.compensate(:step_a, compensations)

      assert Agent.get(log, & &1) == []
    end

    test "compensates nothing when failed step is not in the list" do
      log = Agent.start_link(fn -> [] end) |> elem(1)

      compensations = [
        {:step_a, fn -> Agent.update(log, &[{:compensated, :step_a} | &1]) end}
      ]

      Saga.compensate(:unknown_step, compensations)

      assert Agent.get(log, & &1) == []
    end

    test "compensates all steps when the last step fails" do
      log = Agent.start_link(fn -> [] end) |> elem(1)

      compensations = [
        {:step_a, fn -> Agent.update(log, &[{:compensated, :step_a} | &1]) end},
        {:step_b, fn -> Agent.update(log, &[{:compensated, :step_b} | &1]) end}
      ]

      Saga.compensate(:step_c, compensations)

      assert Agent.get(log, & &1) == [{:compensated, :step_a}, {:compensated, :step_b}]
    end

    test "logs error when compensation function fails" do
      import ExUnit.CaptureLog

      compensations = [
        {:step_a, fn -> {:error, :compensation_failed} end}
      ]

      log =
        capture_log(fn ->
          Saga.compensate(:step_b, compensations)
        end)

      assert log =~ "Saga compensation failed at step_a"
      assert log =~ "compensation_failed"
    end
  end
end
