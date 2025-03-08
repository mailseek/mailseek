defmodule Mailseek.User.UserCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users_categories" do
    field :name, :string
    field :definition, :string
    belongs_to :user, Mailseek.User.Gmail, foreign_key: :user_id

    timestamps()
  end

  def changeset(user_category, attrs) do
    user_category
    |> cast(attrs, [:name, :definition, :user_id])
    |> validate_required([:name, :definition, :user_id])
    |> unique_constraint([:name, :user_id])
  end
end
