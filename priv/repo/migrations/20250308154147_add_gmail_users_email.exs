defmodule Mailseek.Repo.Migrations.AddGmailUsersEmail do
  use Ecto.Migration

  def change do
    alter table(:gmail_users) do
      add :email, :text, null: false
    end
  end
end
