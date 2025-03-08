defmodule Mailseek.Gmail.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gmail_messages" do
    field :subject, :string
    field :from, :string
    field :to, :string
    field :message_id, :string
    field :user_id, :binary_id
    # field :category_id, :binary_id
    field :summary, :string
    field :status, :string

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :subject,
      :from,
      :to,
      :message_id,
      :user_id,
      # :category_id,
      :summary,
      :status
    ])
    |> validate_required([:subject, :from, :to, :message_id, :user_id, :status])
    |> unique_constraint([:message_id, :user_id])
  end

  def update_changeset(message, attrs) do
    message
    |> cast(attrs, [
      :subject,
      # :category_id,
      :summary,
      :status
    ])
    |> validate_required([:subject, :from, :to, :message_id, :user_id, :status])
    |> unique_constraint([:message_id, :user_id])
  end
end
