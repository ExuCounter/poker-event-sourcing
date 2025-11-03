defmodule Poker.Tables.Events.TableCreated do
  @derive {Jason.Encoder, only: [:id, :creator_id, :status, :settings]}
  use Poker, :schema

  embedded_schema do
    field :creator_id, :binary_id
    field :status, Ecto.Enum, values: [:not_started, :live, :finished]
    embeds_one :settings, Poker.Tables.Events.TableSettingsCreated
  end
end
