defmodule MailseekWeb.UserControllerTest do
  use MailseekWeb.ConnCase
  import Mailseek.Factory
  import Mox

  setup :verify_on_exit!

  setup %{conn: conn} do
    user = insert(:user)

    {:ok, token, _} = MailseekWeb.AuthToken.sign(%{"user_id" => user.user_id})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> assign(:current_user, user)

    %{conn: conn, user: user}
  end

  describe "connected_accounts/2" do
    test "returns connected accounts for a user", %{conn: conn, user: user} do
      # Create connected accounts
      connected_user1 = insert(:user)
      connected_user2 = insert(:user)

      insert(:connection, from_user: user, to_user: connected_user1)
      insert(:connection, from_user: user, to_user: connected_user2)

      conn = get(conn, ~p"/api/users/connected_accounts?user_id=#{user.user_id}")

      assert %{"connected_accounts" => accounts} = json_response(conn, 200)
      assert length(accounts) == 2
    end
  end

  describe "list_categories/2" do
    test "returns categories for a user", %{conn: conn, user: user} do
      # Create categories
      insert(:category, user: user, name: "Category 1")
      insert(:category, user: user, name: "Category 2")

      conn = get(conn, ~p"/api/users/categories?user_id=#{user.user_id}")

      assert %{"categories" => categories} = json_response(conn, 200)
      assert length(categories) == 2
    end
  end

  describe "create_category/2" do
    test "creates a new category", %{conn: conn, user: user} do
      params = %{
        "user_id" => user.user_id,
        "name" => "New Category",
        "definition" => "Test definition"
      }

      conn = post(conn, ~p"/api/users/categories", params)

      assert %{"categories" => categories} = json_response(conn, 200)
      assert length(categories) == 1
      assert hd(categories)["name"] == "New Category"
    end

    test "upserts category if already exists", %{conn: conn, user: user} do
      params = %{
        "user_id" => user.user_id,
        "name" => "New Category",
        "definition" => "Test definition"
      }

      conn = post(conn, ~p"/api/users/categories", params)

      conn =
        post(conn, ~p"/api/users/categories", Map.put(params, "definition", "New definition"))

      assert %{"categories" => categories} = json_response(conn, 200)
      assert length(categories) == 1
      assert hd(categories)["name"] == "New Category"
      assert hd(categories)["definition"] == "New definition"
    end
  end

  describe "create_user/2" do
    test "creates a new user", %{conn: conn} do
      # Mock Gmail.initiate_user/1
      expect(Mailseek.MockGmail, :initiate_user, fn _user_id -> :ok end)

      user_id = Ecto.UUID.generate()

      params = %{
        "user_id" => user_id,
        "email" => "new@example.com",
        "access_token" => "access_token",
        "refresh_token" => "refresh_token",
        "expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
      }

      conn = post(conn, ~p"/api/users/google", params)

      assert %{} = json_response(conn, 200)

      # Verify user was created
      assert Mailseek.Gmail.Users.get_user(user_id)
    end

    test "upserts a user but doesnt initiate if already exists", %{conn: conn} do
      # Mock Gmail.initiate_user/1
      expect(Mailseek.MockGmail, :initiate_user, fn _user_id -> :ok end)

      user_id = Ecto.UUID.generate()

      params = %{
        "user_id" => user_id,
        "email" => "new@example.com",
        "access_token" => "access_token",
        "refresh_token" => "refresh_token",
        "expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
      }

      conn = post(conn, ~p"/api/users/google", params)

      assert %{} = json_response(conn, 200)

      conn = post(conn, ~p"/api/users/google", params)

      assert %{} = json_response(conn, 200)

      # Verify user was created
      assert Mailseek.Gmail.Users.get_user(user_id)
    end
  end

  describe "connect/2" do
    test "connects two users", %{conn: conn, user: user} do
      # Mock Gmail.initiate_user/1
      expect(Mailseek.MockGmail, :initiate_user, fn _user_id -> :ok end)

      to_user_id = Ecto.UUID.generate()

      params = %{
        "from" => user.user_id,
        "to" => %{
          "user_id" => to_user_id,
          "email" => "connected@example.com",
          "access_token" => "access_token",
          "refresh_token" => "refresh_token",
          "expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
        }
      }

      conn = post(conn, ~p"/api/users/google/connect", params)

      assert %{} = json_response(conn, 200)

      # Verify connection was created
      connected_accounts = Mailseek.Gmail.Users.get_connected_accounts(user.user_id)
      assert length(connected_accounts) == 1
      assert hd(connected_accounts).user_id == to_user_id
    end
  end
end
