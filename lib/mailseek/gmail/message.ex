defmodule Mailseek.Gmail.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :subject,
             :from,
             :to,
             :message_id,
             :user_id,
             :summary,
             :status,
             :reason,
             :model,
             :sent_at,
             :temperature,
             :need_action,
             :category_id,
             :inserted_at,
             :updated_at
           ]}
  schema "gmail_messages" do
    field :subject, :string
    field :from, :string
    field :to, :string
    field :message_id, :string
    field :user_id, :binary_id
    field :summary, :string
    field :status, :string
    field :reason, :string
    field :model, :string
    field :temperature, :float
    field :need_action, :boolean
    field :sent_at, :naive_datetime

    belongs_to :category, Mailseek.User.UserCategory, foreign_key: :category_id

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
      :summary,
      :status,
      :sent_at
    ])
    |> validate_required([:subject, :from, :to, :message_id, :user_id, :status])
    |> unique_constraint([:message_id, :user_id])
  end

  def update_changeset(message, attrs) do
    message
    |> cast(attrs, [
      :subject,
      :category_id,
      :summary,
      :status,
      :reason,
      :model,
      :temperature,
      :need_action
    ])
    |> validate_required([:subject, :from, :to, :message_id, :user_id, :status])
    |> unique_constraint([:message_id, :user_id])
  end
end
