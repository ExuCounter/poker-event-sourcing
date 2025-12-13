defmodule PokerWeb.PageController do
  use PokerWeb, :controller
  require Logger

  def home(conn, _params) do
    render(conn, :home)
  end
end
