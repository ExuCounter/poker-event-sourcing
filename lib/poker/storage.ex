defmodule Poker.Storage do
  @doc """
  Clear the event store and read store databases
  """
  def reset! do
    reset_eventstore()
    # reset_readstore()
  end

  defp reset_eventstore do
    config = Poker.EventStore.config()

    {:ok, conn} = Postgrex.start_link(config)

    EventStore.Storage.Initializer.reset!(conn, config)
  end

  defp reset_readstore do
    config = Application.get_env(:poker, Poker.Repo)

    {:ok, conn} = Postgrex.start_link(config)

    Postgrex.query!(conn, truncate_readstore_tables(), [])
  end

  defp truncate_readstore_tables do
    """
    TRUNCATE TABLE
      table_pot_winners,
      table_pots,
      tables,
      table_participants,
      table_participant_hands,
      table_rounds,
      table_list,
      table_lobby,
      projection_versions
    RESTART IDENTITY
    CASCADE;
    """
  end

  # defp truncate_subscriptions do
  #   """
  #   TRUNCATE TABLE
  #     subscriptions
  #   RESTART IDENTITY
  #   CASCADE;
  #   """
  # end
end
