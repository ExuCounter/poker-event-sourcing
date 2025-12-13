defmodule PokerWeb.TableController do
  use PokerWeb, :controller
  require Logger

  def create(conn, _params) do
    case PokerWeb.Api.Tables.create_table(conn.assigns.current_scope, %{
           small_blind: 10,
           big_blind: 20,
           starting_stack: 1000,
           timeout_seconds: 90,
           table_type: :six_max
         }) do
      {:ok, %{table_id: table_id}} ->
        redirect(conn, to: ~p"/tables/#{table_id}/lobby")

      {:error, reason} ->
        Logger.error("Failed to create table: #{inspect(reason)}")

        conn
        |> put_flash(:error, formatted_reason(:create, reason))
        |> redirect(to: ~p"/")
    end
  end

  def formatted_reason(:create, _), do: "Failed to create table"
end
