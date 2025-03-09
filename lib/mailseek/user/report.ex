defmodule Mailseek.User.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [:id, :status, :summary, :payload, :type, :inserted_at, :message_id, :user_id]}
  schema "reports" do
    field :status, Ecto.Enum, values: [:pending, :success, :error]
    field :summary, :string
    field :payload, :map
    field :type, :string
    belongs_to :user, Mailseek.User.Gmail, foreign_key: :user_id
    belongs_to :message, Mailseek.Gmail.Message, foreign_key: :message_id

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:status, :summary, :payload, :user_id, :message_id, :type])
    |> validate_required([:status, :user_id, :type])
  end
end
