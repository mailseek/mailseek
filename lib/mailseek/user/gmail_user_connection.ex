defmodule Mailseek.User.GmailUserConnection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gmail_users_connections" do
    belongs_to :from_user, Mailseek.User.Gmail, foreign_key: :from_user_id
    belongs_to :to_user, Mailseek.User.Gmail, foreign_key: :to_user_id

    field :expires_at, :integer

    timestamps()
  end

  def changeset(gmail_user_connection, attrs) do
    gmail_user_connection
    |> cast(attrs, [:from_user_id, :to_user_id, :expires_at])
    |> validate_required([:from_user_id, :to_user_id, :expires_at])
    |> unique_constraint([:from_user_id, :to_user_id])
  end
end
