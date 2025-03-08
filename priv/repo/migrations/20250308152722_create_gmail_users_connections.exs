defmodule Mailseek.Repo.Migrations.CreateGmailUsersConnections do
  use Ecto.Migration

  def change do
    create table(:gmail_users_connections) do
      add :from_user_id, references(:gmail_users, on_delete: :delete_all)
      add :to_user_id, references(:gmail_users, on_delete: :delete_all)
      add :expires_at, :integer

      timestamps()
    end

    create unique_index(:gmail_users_connections, [:from_user_id, :to_user_id])
  end
end
