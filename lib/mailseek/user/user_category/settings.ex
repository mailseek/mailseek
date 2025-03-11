defmodule Mailseek.User.UserCategory.Settings do
  use Ecto.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :key, :value, :category_id, :user_id]}
  schema "users_categories_settings" do
    belongs_to :user, Mailseek.User.Gmail
    belongs_to :category, Mailseek.Message.Category
    field :key, :string
    field :value, :map

    timestamps()
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:key, :value, :user_id, :category_id])
    |> validate_required([:key, :value, :user_id, :category_id])
    |> unique_constraint([:user_id, :category_id, :key])
  end
end
