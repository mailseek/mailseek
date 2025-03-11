defmodule Mailseek.User.Gmail do
  use Ecto.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :email, :user_id]}
  schema "gmail_users" do
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :integer
    field :history_id, :string
    field :email, :string
    field :user_id, :binary_id

    has_many :categories, Mailseek.Message.Category, foreign_key: :user_id
    has_many :connected_accounts, Mailseek.User.GmailUserConnection, foreign_key: :from_user_id
    timestamps()
  end

  def changeset(gmail_user, attrs) do
    gmail_user
    |> cast(attrs, [:access_token, :refresh_token, :expires_at, :history_id, :email, :user_id])
    |> validate_required([:access_token, :refresh_token, :expires_at, :email, :user_id])
    |> unique_constraint([:user_id])
  end

  def update_changeset(gmail_user, attrs) do
    gmail_user
    |> cast(attrs, [:access_token, :refresh_token, :expires_at, :history_id])
    |> validate_required([:access_token, :refresh_token, :expires_at])
  end
end
