defmodule Poker.Saga do
  require Logger

  @moduledoc """
  Compensating saga helper for multi-step operations.

  Used with tagged `with` chains to revert successful steps when a later step fails.
  Compensatable steps are listed in execution order. When a step fails, all preceding
  steps are compensated in reverse order.
  """

  def compensate(failed_step, compensations) do
    compensations
    |> Enum.take_while(fn {step, _} -> step != failed_step end)
    |> Enum.reverse()
    |> Enum.each(fn {step, fun} ->
      case fun.() do
        :ok -> :ok
        {:ok, _} -> :ok
        error ->
          Logger.error("Saga compensation failed at #{step}: #{inspect(error)}")
      end
    end)
  end
end
