defmodule Mailseek.Repo.Migrations.UpdateUsersCategoriesView do
  use Ecto.Migration

  def change do
    execute("""
    CREATE OR REPLACE VIEW v_user_categories AS
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
    gmail_messages gm ON
    gm.category_id = uc.id AND
    gm.status <> 'deleted' AND
    (
      gm.user_id = gu.user_id OR
      gm.user_id IN (
        SELECT cgu.user_id
        FROM gmail_users_connections guc
        JOIN gmail_users cgu ON cgu.id = guc.to_user_id
        WHERE guc.from_user_id = uc.user_id
      )
    )
    GROUP BY
    uc.id, uc.name, uc.definition, uc.user_id

    """)
  end

  def down do
    execute("DROP VIEW IF EXISTS v_user_categories")
  end
end
