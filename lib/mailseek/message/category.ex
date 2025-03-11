defmodule Mailseek.Message.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :definition, :message_count, :user_id]}
  schema "v_user_categories" do
    field :name, :string
    field :definition, :string
    field :message_count, :integer
    belongs_to :user, Mailseek.User.Gmail, foreign_key: :user_id
  end
end
