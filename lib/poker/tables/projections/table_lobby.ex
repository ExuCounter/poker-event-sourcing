defmodule Poker.Tables.Projections.TableLobby do
  use Poker, :schema

  defmodule Participant do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :participant_id, :binary_id
      field :player_id, :binary_id
      field :email, :string
      field :nickname, :string
      field :status, Ecto.Enum, values: [:active, :busted], default: :active
      field :seat_number, :integer
    end
  end

  schema "table_lobby" do
    field :status, Ecto.Enum, values: [:waiting, :live, :paused, :finished]
    field :seated_count, :integer
    field :seats_count, :integer
    field :source_id, :binary_id
    field :game_mode, Ecto.Enum, values: [:cash_game, :tournament]

    embeds_many :participants, Participant, on_replace: :delete

    timestamps()
  end
end
