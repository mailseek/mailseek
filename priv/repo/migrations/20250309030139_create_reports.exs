defmodule Mailseek.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :user_id, references(:gmail_users, on_delete: :delete_all), null: false
      add :message_id, references(:gmail_messages, on_delete: :delete_all)
      add :status, :string, null: false
      add :summary, :text
      add :payload, :map, default: "{}"
      add :type, :string, null: false

      timestamps()
    end

    create index(:reports, [:message_id, :user_id])
  end
end
