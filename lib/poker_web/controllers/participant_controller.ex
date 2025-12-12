defmodule PokerWeb.ParticipantController do
  use PokerWeb, :controller
  require Logger

  def create(conn, %{"table_id" => table_id} = params) do
    case PokerWeb.Api.Tables.join_participant(conn.assigns.current_scope, %{table_id: table_id}) do
      {:ok, _data} ->
        redirect(conn, to: ~p"/tables/#{table_id}/lobby")

      {:error, reason} ->
        Logger.error("Failed to join table: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to join table")
        |> redirect(to: ~p"/")
    end
  end
end
