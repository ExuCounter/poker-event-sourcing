defmodule Poker.Telemetry do
  @moduledoc """
  Telemetry helpers for the poker domain.

  Event taxonomy:

      [:poker, :command, <name>, :start | :stop | :exception]

  Each wrapped command also creates an OpenTelemetry span named
  `poker.command.<name>`. Span attributes are populated from the `base_meta`
  map. An `{:error, _}` return sets the span status to error; unhandled
  exceptions are recorded automatically.

  ## Usage

      Poker.Telemetry.span_command(:raise, %{table_id: id, player_id: pid}, fn ->
        do_work()
      end)

  To attach extra metadata derived from the result, return
  `{:meta, result, extra_meta}` from the function:

      Poker.Telemetry.span_command(:raise, base_meta, fn ->
        case do_work() do
          {:ok, hand} -> {:meta, {:ok, hand}, %{pot_size: hand.pot}}
          err -> err
        end
      end)
  """

  require OpenTelemetry.Tracer

  @type command_name :: atom()
  @type metadata :: map()

  @spec span_command(command_name(), metadata(), (-> any())) :: any()
  def span_command(name, base_meta, fun)
      when is_atom(name) and is_map(base_meta) and is_function(fun, 0) do
    OpenTelemetry.Tracer.with_span "poker.command.#{name}",
      %{kind: :internal, attributes: to_otel_attrs(base_meta)} do
      result =
        :telemetry.span([:poker, :command, name], base_meta, fn ->
          case fun.() do
            {:meta, result, extra_meta} when is_map(extra_meta) ->
              {result, Map.merge(base_meta, extra_meta)}

            result ->
              {result, base_meta}
          end
        end)

      case result do
        {:error, %{message: msg}} when is_binary(msg) ->
          OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, msg))

        {:error, reason} ->
          OpenTelemetry.Tracer.set_status(OpenTelemetry.status(:error, inspect(reason)))

        _ ->
          :ok
      end

      result
    end
  end

  defp to_otel_attrs(meta) do
    Map.new(meta, fn {k, v} -> {to_string(k), to_otel_value(v)} end)
  end

  defp to_otel_value(v) when is_binary(v) or is_integer(v) or is_float(v) or is_boolean(v), do: v
  defp to_otel_value(nil), do: "nil"
  defp to_otel_value(v), do: inspect(v)
end
