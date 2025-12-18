defmodule PokerWeb.PlayerLive.Lobby do
  use PokerWeb, :live_view

  alias PokerWeb.Api.Tables

  @impl true
  def mount(%{"id" => table_id}, _session, socket) do
    case Tables.get_lobby(table_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Table lobby not found")
         |> push_navigate(to: ~p"/")}

      lobby ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Poker.PubSub, "table:#{table_id}:lobby")
        end

        {:ok, assign(socket, lobby: lobby, table_id: table_id)}
    end
  end

  @impl true
  def handle_event("join_table", _params, socket) do
    case Tables.join_participant(socket.assigns.current_scope, %{
           table_id: socket.assigns.table_id
         }) do
      {:ok, _participant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the table")
         |> assign(lobby: Tables.get_lobby(socket.assigns.table_id))}

      {:error, %{message: message}} ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join table: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("start_table", _params, socket) do
    case Tables.start_table(socket.assigns.current_scope, socket.assigns.table_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Table started!")
         |> push_navigate(to: ~p"/tables/#{socket.assigns.table_id}/game")}

      {:error, :table_already_started} ->
        {:noreply, put_flash(socket, :error, "Table has already started")}

      {:error, :not_enough_participants} ->
        {:noreply, put_flash(socket, :error, "Need at least 2 players to start")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start table: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:table_lobby, :table_started, %{table_id: table_id}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/tables/#{table_id}/game")}
  end

  def handle_info({:table_lobby, _event, _data}, socket) do
    lobby = Tables.get_lobby(socket.assigns.table_id)
    {:noreply, assign(socket, lobby: lobby)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash kind={:error} flash={@flash} />
    <div class="flex p-10">
      <div class="flex-col w-full max-w-4xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/"} class="text-blue-600 hover:text-blue-800">
            &larr; Back to Tables List
          </.link>
        </div>

        <h1 class="text-3xl font-bold mb-6">Table Lobby</h1>

        <div class="shadow-md rounded-lg p-6 mb-6">
          <h2 class="text-xl font-semibold mb-4">Table Information</h2>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <p class="text-gray-600">Table Type</p>
              <p class="font-semibold capitalize">{@lobby.table_type}</p>
            </div>

            <div>
              <p class="text-gray-600">Status</p>
              <p class="font-semibold capitalize">{@lobby.status}</p>
            </div>

            <div>
              <p class="text-gray-600">Small Blind</p>
              <p class="font-semibold">{@lobby.small_blind}</p>
            </div>

            <div>
              <p class="text-gray-600">Big Blind</p>
              <p class="font-semibold">{@lobby.big_blind}</p>
            </div>

            <div>
              <p class="text-gray-600">Starting Stack</p>
              <p class="font-semibold">{@lobby.starting_stack}</p>
            </div>

            <div>
              <p class="text-gray-600">Players</p>
              <p class="font-semibold">{@lobby.seated_count}/{@lobby.seats_count}</p>
            </div>
          </div>
        </div>

        <div class="shadow-md rounded-lg p-6">
          <h2 class="text-xl font-semibold mb-4">Players ({@lobby.seated_count})</h2>

          <div class="space-y-2 mb-6">
            <%= if Enum.empty?(@lobby.participants) do %>
              <p class="text-gray-500">No players yet</p>
            <% else %>
              <%= for participant <- @lobby.participants do %>
                <div class="flex items-center gap-2 border-b pb-2">
                  <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                  <p class="font-medium">{participant.email}</p>
                </div>
              <% end %>
            <% end %>
          </div>

          <div class="flex gap-4">
            <%= if @lobby.seated_count < @lobby.seats_count do %>
              <.button phx-click="join_table">Join Table</.button>
            <% else %>
              <div class="text-gray-500">Table is full ({@lobby.seats_count} max)</div>
            <% end %>

            <%= if @lobby.status == :waiting && @lobby.seated_count >= 2 do %>
              <.button phx-click="start_table" class="bg-green-600 hover:bg-green-700">
                Start Game
              </.button>
            <% end %>

            <%= if @lobby.status == :live do %>
              <.link navigate={~p"/tables/#{@lobby.id}/game"}>
                <.button>
                  Play the game
                </.button>
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
