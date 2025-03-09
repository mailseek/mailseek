defmodule Mailseek.Repo.Migrations.AddGmailMessagesSentAt do
  use Ecto.Migration

  def change do
    alter table(:gmail_messages) do
      add :sent_at, :naive_datetime
    end

    create index(:gmail_messages, [:sent_at])
  end
end
