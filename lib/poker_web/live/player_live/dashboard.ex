defmodule PokerWeb.PlayerLive.Dashboard do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Poker.PubSub, "table_list")
    end

    {:ok, assign(socket, tables_list: Tables.list_tables(), form: to_form(%{}))}
  end

  @impl true
  def handle_event("create_table", %{"table" => params}, socket) do
    settings = %{
      small_blind: String.to_integer(params["small_blind"]),
      big_blind: String.to_integer(params["big_blind"]),
      starting_stack: String.to_integer(params["starting_stack"]),
      timeout_seconds: String.to_integer(params["timeout_seconds"]),
      table_type: String.to_existing_atom(params["table_type"])
    }

    case Tables.create_table(socket.assigns.current_scope, settings) do
      {:ok, %{table_id: table_id}} ->
        {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/lobby")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create table: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:table_list, _event, _data}, socket) do
    {:noreply, assign(socket, tables_list: Tables.list_tables())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex p-10 gap-8">
      <div class="flex-1">
        <h2 class="text-xl font-semibold mb-4">Tables</h2>

        <div class="flex flex-col">
          <%= if Enum.empty?(@tables_list) do %>
            <p class="text-gray-500">No live tables</p>
          <% else %>
            <%= for table <- @tables_list do %>
              <div class="border-b py-3 hover:bg-gray-50">
                <.link
                  navigate={~p"/tables/#{table.id}/lobby"}
                  class="text-blue-600 hover:text-blue-800"
                >
                  NL Holdem | Players: {table.seated_count}/{table.seats_count} | Status: {table.status}
                </.link>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="w-80">
        <h2 class="text-xl font-semibold mb-4">Create Table</h2>

        <.form for={@form} phx-submit="create_table" class="flex flex-col gap-4">
          <.input type="number" name="table[small_blind]" label="Small Blind" value="10" />
          <.input type="number" name="table[big_blind]" label="Big Blind" value="20" />
          <.input type="number" name="table[starting_stack]" label="Starting Stack" value="1000" />
          <.input type="number" name="table[timeout_seconds]" label="Timeout" value="90" />
          <.input
            type="select"
            name="table[table_type]"
            label="Table Type"
            options={[{"6-Max", "six_max"}]}
            value="six_max"
          />

          <.button type="submit">Create Table</.button>
        </.form>
      </div>
    </div>
    """
  end
end
