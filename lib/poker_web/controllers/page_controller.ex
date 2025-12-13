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
end
