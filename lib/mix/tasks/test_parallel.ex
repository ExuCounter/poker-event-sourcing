defmodule Mix.Tasks.Test.Parallel do
  @shortdoc "Run tests in parallel across multiple BEAM instances"
  @moduledoc """
  Runs the test suite across multiple partitions, each in its own BEAM process.

  ## Usage

      mix test.parallel              # 8 partitions (default)
      mix test.parallel --partitions 4
      mix test.parallel --partitions 4 test/poker/tables

  Any extra arguments are forwarded to `mix test`.
  """

  use Mix.Task

  @default_partitions 8

  @impl Mix.Task
  def run(args) do
    {partitions, test_args} = parse_args(args)

    setup_databases(partitions)

    IO.puts("Running tests across #{partitions} partitions...\n")
    start = System.monotonic_time(:millisecond)

    tasks =
      for i <- 1..partitions do
        Task.async(fn -> run_partition(i, partitions, test_args) end)
      end

    results = Task.await_many(tasks, :infinity)

    elapsed = System.monotonic_time(:millisecond) - start
    failures = Enum.count(results, fn code -> code != 0 end)

    IO.puts("\nFinished in #{elapsed / 1000}s across #{partitions} partitions")

    if failures > 0 do
      IO.puts("#{failures} partition(s) had failures")
      System.halt(1)
    end
  end

  defp parse_args(args) do
    case OptionParser.parse_head(args, strict: [partitions: :integer]) do
      {opts, rest, _} ->
        {Keyword.get(opts, :partitions, @default_partitions), rest}
    end
  end

  defp setup_databases(partitions) do
    for i <- 1..partitions do
      System.cmd("mix", ["ecto.create", "--quiet"],
        env: [{"MIX_TEST_PARTITION", to_string(i)}, {"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

      System.cmd("mix", ["ecto.migrate", "--quiet"],
        env: [{"MIX_TEST_PARTITION", to_string(i)}, {"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )
    end
  end

  defp run_partition(partition, total, extra_args) do
    args = ["test", "--partitions", to_string(total)] ++ extra_args

    port =
      Port.open(
        {:spawn_executable, System.find_executable("mix")},
        [
          :exit_status,
          :binary,
          :stderr_to_stdout,
          args: args,
          env: [
            {~c"MIX_TEST_PARTITION", ~c"#{partition}"},
            {~c"MIX_ENV", ~c"test"}
          ]
        ]
      )

    stream_output(port, partition)
  end

  defp stream_output(port, partition) do
    receive do
      {^port, {:data, data}} ->
        data
        |> String.split("\n")
        |> Enum.each(fn line ->
          if line != "", do: IO.puts("[P#{partition}] #{line}")
        end)

        stream_output(port, partition)

      {^port, {:exit_status, code}} ->
        code
    end
  end
end
