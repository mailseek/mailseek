defmodule Mailseek.Gmail.UserCategoriesTest do
  use Mailseek.DataCase

  alias Mailseek.Gmail.UserCategories
  alias Mailseek.User.UserCategory.Settings
  alias Mailseek.Repo
  import Mailseek.Factory

  import Mox

  setup :verify_on_exit!

  setup do
    Mox.stub_with(Mailseek.MockUsers, Mailseek.Gmail.Users)
    :ok
  end

  describe "save_category_settings/3" do
    test "saves new settings for a user and category" do
      # Setup
      user = insert(:user)
      category = insert(:category, user: user)
      category_id = category.id

      items = [
        %{key: "archive_categorized_emails", value: %{"type" => "boolean", "value" => false}}
      ]

      # Execute
      result = UserCategories.save_category_settings(user.user_id, category_id, items)

      # Verify
      assert length(result) == 1
      [saved_setting] = result
      assert saved_setting.user_id == user.id
      assert saved_setting.category_id == category_id
      assert saved_setting.key == "archive_categorized_emails"
      assert saved_setting.value == %{"type" => "boolean", "value" => false}
    end

    test "updates existing settings on conflict" do
      # Setup
      user = insert(:user)
      category = insert(:category, user: user)
      category_id = category.id

      # Create initial setting
      initial_item = %{
        key: "archive_categorized_emails",
        value: %{"type" => "boolean", "value" => true}
      }

      UserCategories.save_category_settings(user.user_id, category_id, [initial_item])

      # Update with new value
      updated_item = %{
        key: "archive_categorized_emails",
        value: %{"type" => "boolean", "value" => false}
      }

      # Execute
      result = UserCategories.save_category_settings(user.user_id, category_id, [updated_item])

      # Verify
      assert length(result) == 1
      [saved_setting] = result
      assert saved_setting.value == %{"type" => "boolean", "value" => false}

      # Verify only one record exists
      count = Repo.aggregate(Settings, :count)
      assert count == 1
    end
  end

  describe "get_category_settings/2" do
    test "returns existing settings for a user and category" do
      # Setup
      user = insert(:user)
      category = insert(:category, user: user)
      category_id = category.id

      # Create a setting
      %Settings{}
      |> Settings.changeset(%{
        user_id: user.id,
        category_id: category_id,
        key: "archive_categorized_emails",
        value: %{"type" => "boolean", "value" => false}
      })
      |> Repo.insert!()

      # Execute
      result = UserCategories.get_category_settings(user.user_id, category_id)

      # Verify
      assert %{items: items} = result
      assert length(items) == 1
      [item] = items
      assert item.key == "archive_categorized_emails"
      assert item.value == %{"type" => "boolean", "value" => false}
    end

    test "fills in default settings when none exist" do
      # Setup
      user = insert(:user)
      category = insert(:category, user: user)
      category_id = category.id

      # Execute
      result = UserCategories.get_category_settings(user.user_id, category_id)

      # Verify
      assert %{items: items} = result
      assert length(items) == 1
      [item] = items
      assert item.key == "archive_categorized_emails"
      assert item.value == %{"type" => "boolean", "value" => true}
    end

    test "merges existing settings with defaults" do
      # Setup
      user = insert(:user)
      category = insert(:category, user: user)
      category_id = category.id

      # Create a custom setting (not in defaults)
      %Settings{}
      |> Settings.changeset(%{
        user_id: user.id,
        category_id: category_id,
        key: "archive_categorized_emails",
        value: %{"type" => "boolean", "value" => false}
      })
      |> Repo.insert!()

      # Execute
      result = UserCategories.get_category_settings(user.user_id, category_id)

      # Verify
      assert %{items: items} = result
      assert length(items) == 1

      archive_setting = Enum.find(items, fn item -> item.key == "archive_categorized_emails" end)
      assert archive_setting.value == %{"type" => "boolean", "value" => false}
    end
  end
end
