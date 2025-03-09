defmodule Mailseek.Gmail.UsersTest do
  use Mailseek.DataCase

  import Mailseek.Factory

  alias Mailseek.Gmail.Users
  alias Mailseek.User.Gmail, as: GmailUser
  alias Mailseek.User.UserCategory
  alias Mailseek.Repo

  describe "get_user/1" do
    test "returns the user with the given user_id" do
      user = insert(:user)

      result = Users.get_user(user.user_id)

      assert %GmailUser{} = result
      assert result.id == user.id
      assert result.user_id == user.user_id
      assert result.email == user.email
    end

    test "raises if user doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Users.get_user(Ecto.UUID.generate())
      end
    end
  end

  describe "get_connected_accounts/1" do
    test "returns connected accounts for a user" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      # Connect user1 to user2 and user3
      insert(:connection, from_user: user1, to_user: user2)
      insert(:connection, from_user: user1, to_user: user3)

      result = Users.get_connected_accounts(user1.user_id)

      assert length(result) == 2
      assert Enum.any?(result, fn account -> account.id == user2.id end)
      assert Enum.any?(result, fn account -> account.id == user3.id end)
    end

    test "returns empty list when user has no connections" do
      user = insert(:user)

      result = Users.get_connected_accounts(user.user_id)

      assert result == []
    end
  end

  describe "related_user_ids/1" do
    test "returns user IDs of connected accounts and the user's own ID" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      # Connect user1 to user2 and user3
      insert(:connection, from_user: user1, to_user: user2)
      insert(:connection, from_user: user1, to_user: user3)

      result = Users.related_user_ids(user1.user_id)

      assert length(result) == 3
      assert user1.user_id in result
      assert user2.user_id in result
      assert user3.user_id in result
    end

    test "returns only the user's own ID when no connections exist" do
      user = insert(:user)

      result = Users.related_user_ids(user.user_id)

      assert result == [user.user_id]
    end
  end

  describe "get_categories/1" do
    test "returns categories for a user" do
      user = insert(:user)

      # Create categories for the user
      category1 = insert(:category, user: user)
      category2 = insert(:category, user: user)

      result = Users.get_categories(user.user_id)

      assert length(result) == 2
      assert Enum.any?(result, fn cat -> cat.id == category1.id end)
      assert Enum.any?(result, fn cat -> cat.id == category2.id end)
    end

    test "returns empty list when user has no categories" do
      user = insert(:user)

      result = Users.get_categories(user.user_id)

      assert result == []
    end
  end

  describe "categories_for_account/1" do
    test "returns categories for the primary account" do
      primary_user = insert(:user)
      secondary_user = insert(:user)

      # Connect secondary_user to primary_user
      insert(:connection, from_user: primary_user, to_user: secondary_user)

      # Create categories for the primary user
      category1 = insert(:category, user: primary_user)
      category2 = insert(:category, user: primary_user)

      # Create a category for the secondary user (should not be returned)
      _secondary_category = insert(:category, user: secondary_user)

      result = Users.categories_for_account(secondary_user.user_id)

      assert length(result) == 2
      assert Enum.any?(result, fn cat -> cat.id == category1.id end)
      assert Enum.any?(result, fn cat -> cat.id == category2.id end)
    end

    test "returns user's own categories when user is primary" do
      user = insert(:user)

      # Create categories for the user
      category1 = insert(:category, user: user)
      category2 = insert(:category, user: user)

      result = Users.categories_for_account(user.user_id)

      assert length(result) == 2
      assert Enum.any?(result, fn cat -> cat.id == category1.id end)
      assert Enum.any?(result, fn cat -> cat.id == category2.id end)
    end
  end

  describe "upsert_category/1" do
    test "creates a new category" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        name: "Test Category",
        definition: "Test Definition"
      }

      result = Users.upsert_category(attrs)

      assert %UserCategory{} = result
      assert result.user_id == attrs.user_id
      assert result.name == attrs.name
      assert result.definition == attrs.definition
    end

    test "updates existing category on conflict" do
      user = insert(:user)

      # Create initial category
      initial_attrs = %{
        user_id: user.id,
        name: "Test Category",
        definition: "Initial Definition"
      }

      Users.upsert_category(initial_attrs)

      # Update category
      update_attrs = %{
        user_id: user.id,
        name: "Test Category",
        definition: "Updated Definition"
      }

      result = Users.upsert_category(update_attrs)

      assert %UserCategory{} = result
      assert result.user_id == update_attrs.user_id
      assert result.name == update_attrs.name
      assert result.definition == update_attrs.definition

      # Verify only one category exists with this name
      categories = Repo.all(from c in UserCategory, where: c.name == "Test Category")
      assert length(categories) == 1
    end
  end

  describe "get_primary_account/1" do
    test "returns the primary account for a connected user" do
      primary_user = insert(:user)
      secondary_user = insert(:user)

      # Connect secondary_user to primary_user
      insert(:connection, from_user: primary_user, to_user: secondary_user)

      result = Users.get_primary_account(secondary_user)

      assert %GmailUser{} = result
      assert result.id == primary_user.id
    end

    test "returns the user itself when no connection exists" do
      user = insert(:user)

      result = Users.get_primary_account(user)

      assert %GmailUser{} = result
      assert result.id == user.id
    end
  end
end
