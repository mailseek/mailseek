defmodule Mailseek.Repo.Migrations.CreateGmailMessages do
  use Ecto.Migration

  def change do
    create table(:gmail_messages) do
      add :subject, :text
      add :from, :text
      add :to, :text
      add :message_id, :string, null: false
      add :user_id, :binary_id, null: false
      add :summary, :text
      add :status, :string, null: false
      add :reason, :text
      add :model, :string
      add :temperature, :float
      add :need_action, :boolean

      timestamps()
    end

    create unique_index(:gmail_messages, [:message_id, :user_id])
    create index(:gmail_messages, [:status])
  end
end
