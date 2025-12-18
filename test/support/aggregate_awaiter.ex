defmodule Poker.TestSupport.ProcessManagerAwaiter do
  @moduledoc """
  Handles eventual consistency in tests.

  Our system uses process managers which dispatch commands asynchronously.
  There's no reliable way to know when a chain completes, so we wait
  for the system to settle.
  """

  @settle_time_ms 100

  def wait_to_settle do
    Process.sleep(@settle_time_ms)
  end
end
