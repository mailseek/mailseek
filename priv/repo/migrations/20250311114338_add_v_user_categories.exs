defmodule Mailseek.Repo.Migrations.AddVUserCategories do
  use Ecto.Migration

  def up do
    execute("""
    CREATE VIEW v_user_categories AS
    SELECT
        uc.id,
        uc.name,
        uc.definition,
        uc.user_id,
        COUNT(gm.id) AS message_count
    FROM
        users_categories uc
    LEFT JOIN
        gmail_users gu ON gu.id = uc.user_id
    LEFT JOIN
        gmail_messages gm ON gm.category_id = uc.id AND gm.user_id = gu.user_id AND gm.status != 'deleted'
    GROUP BY
        uc.id, uc.name, uc.definition, uc.user_id
    """)
  end

  def down do
    execute("DROP VIEW IF EXISTS v_user_categories")
  end
end
