defmodule Mailseek.Repo.Migrations.CreateGmailUsers do
  use Ecto.Migration

  def change do
    create table(:gmail_users) do
      add :user_id, :uuid, null: false
      add :access_token, :string, null: false
      add :refresh_token, :string, null: false
      add :expires_at, :integer, null: false
      add :history_id, :string

      timestamps()
    end

    create unique_index(:gmail_users, [:user_id])
  end
end
