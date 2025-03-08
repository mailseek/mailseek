defmodule Mailseek.Repo.Migrations.CreateGmailMessages do
  use Ecto.Migration

  def change do
    create table(:gmail_messages) do
      add :subject, :string
      add :from, :string
      add :to, :string
      add :message_id, :string, null: false
      add :user_id, :binary_id, null: false
      add :summary, :string
      add :status, :string

      timestamps()
    end

    create unique_index(:gmail_messages, [:message_id, :user_id])
  end
end
