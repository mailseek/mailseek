defmodule Mailseek.Repo.Migrations.UsersCategoriesSettings do
  use Ecto.Migration

  def change do
    create table(:users_categories_settings) do
      add :user_id, references(:gmail_users), null: false
      add :category_id, references(:users_categories), null: false
      add :key, :string, null: false
      add :value, :map, null: false, default: "{}"

      timestamps()
    end

    create unique_index(:users_categories_settings, [:user_id, :category_id, :key],
             name: "users_categories_settings_user_id_category_id_key_index"
           )

    create index(:users_categories_settings, [:user_id, :category_id])
  end
end
