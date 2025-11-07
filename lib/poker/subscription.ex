defmodule Poker.Subscription do
  use GenServer
  require Logger

  alias Poker.EventStore

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    {:ok, subscription} =
      EventStore.subscribe_to_all_streams("example_single_subscription", self())

    Logger.info("✅ Subscribed to all streams")

    {:ok, %{subscription: subscription}}
  end

  @impl true
  def handle_info({:events, events}, %{subscription: subscription} = state) do
    # Process the events here
    dbg(events)

    # Acknowledge events after processing
    :ok = EventStore.ack(subscription, events)

    {:noreply, state}
  end

  @impl true
  def handle_info({:subscribed, subscription}, state) do
    Logger.info("✅ Subscription confirmed: #{inspect(subscription)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end
end
