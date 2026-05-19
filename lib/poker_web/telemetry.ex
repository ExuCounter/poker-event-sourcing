defmodule PokerWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus.Core, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      distribution("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000]]
      ),
      distribution("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000]]
      ),
      distribution("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000]]
      ),
      distribution("phoenix.socket_connected.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000]]
      ),
      sum("phoenix.socket_drain.count"),
      distribution("phoenix.channel_joined.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000]]
      ),
      distribution("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000]]
      ),

      # Database Metrics
      distribution("poker.repo.query.total_time",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]]
      ),
      distribution("poker.repo.query.query_time",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]]
      ),
      distribution("poker.repo.query.queue_time",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250]]
      ),
      distribution("poker.repo.query.decode_time",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100]]
      ),
      distribution("poker.repo.query.idle_time",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250]]
      ),

      # VM Metrics
      last_value("vm.memory.total", unit: {:byte, :kilobyte}),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    []
  end
end
