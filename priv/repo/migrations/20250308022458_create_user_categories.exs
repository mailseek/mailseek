defmodule Mailseek.Repo.Migrations.CreateUserCategories do
  use Ecto.Migration

  def change do
    create table(:users_categories) do
      add :name, :string, null: false
      add :definition, :text
      add :user_id, references(:gmail_users), null: false

      timestamps()
    end

    create unique_index(:users_categories, [:name, :user_id])
    create index(:users_categories, [:user_id])

    alter table(:gmail_messages) do
      add :category_id, references(:users_categories)
    end

    create index(:gmail_messages, [:category_id])
  end
end
