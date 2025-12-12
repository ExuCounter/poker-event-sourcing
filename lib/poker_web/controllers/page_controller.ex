defmodule PokerWeb.PageController do
  use PokerWeb, :controller
  require Logger

  def home(conn, _params) do
    render(conn, :home)
  end

  def dashboard(conn, _params) do
    tables_list = PokerWeb.Api.Tables.list_tables()

    render(conn, :dashboard, tables_list: tables_list)
  end

  def lobby(conn, %{"id" => table_id}) do
    case PokerWeb.Api.Tables.get_lobby(table_id) do
      nil ->
        conn
        |> put_flash(:error, "Table not found")
        |> redirect(to: ~p"/")

      lobby ->
        render(conn, :lobby, lobby: lobby)
    end
  end

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
        |> put_flash(:error, "Failed to create table")
        |> redirect(to: ~p"/")
    end
  end
end
