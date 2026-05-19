defmodule PokerWeb.MetricsController do
  use PokerWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, TelemetryMetricsPrometheus.Core.scrape())
  end
end
