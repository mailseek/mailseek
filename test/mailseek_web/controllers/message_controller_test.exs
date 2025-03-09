defmodule MailseekWeb.MessageControllerTest do
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

    # Create some messages for the user
    messages = insert_list(3, :message, user_id: user.user_id)

    %{conn: conn, user: user, messages: messages}
  end

  describe "index/2" do
    test "returns messages with no category", %{conn: conn, user: user, messages: messages} do
      conn = get(conn, ~p"/api/messages?category_id=no_category&user_id=#{user.user_id}")

      assert %{"messages" => returned_messages} = json_response(conn, 200)
      assert length(returned_messages) == length(messages)
    end

    test "returns messages with specific category", %{conn: conn, user: user} do
      # Create a category
      category = insert(:category, user: user)

      # Create messages with that category
      categorized_messages =
        insert_list(2, :message, user_id: user.user_id, category_id: category.id)

      conn = get(conn, ~p"/api/messages?category_id=#{category.id}&user_id=#{user.user_id}")

      assert %{"messages" => returned_messages} = json_response(conn, 200)
      assert length(returned_messages) == length(categorized_messages)
    end
  end

  describe "delete/2" do
    test "deletes messages", %{conn: conn, user: user, messages: messages} do
      # Mock necessary functions
      expect(Mailseek.MockUsers, :related_user_ids, fn user_id ->
        assert user_id == user.user_id
        [user.user_id]
      end)

      times = length(messages)

      expect(Mailseek.MockUsers, :get_user, times, fn user_id ->
        assert user_id == user.user_id
        user
      end)

      expect(Mailseek.MockUsers, :get_primary_account, times, fn user ->
        user
      end)

      expect(Mailseek.MockNotifications, :notify, times, fn "emails:all",
                                                            {event, data, user_id} ->
        assert event == :email_updated
        assert %{message: _} = data
        assert user_id == user.user_id
        :ok
      end)

      message_ids = Enum.map(messages, & &1.message_id)

      conn =
        post(conn, ~p"/api/messages/delete", %{
          "message_ids" => message_ids,
          "user_id" => user.user_id
        })

      assert %{"message" => "Messages deleted", "messages" => deleted_messages} =
               json_response(conn, 200)

      assert length(deleted_messages) == length(messages)

      # Verify all messages are marked as deleted
      for message <- deleted_messages do
        assert message["status"] == "deleted"
      end
    end
  end

  describe "unsubscribe/2" do
    test "marks messages for unsubscribing", %{conn: conn, user: user, messages: messages} do
      # Mock necessary functions
      expect(Mailseek.MockUsers, :related_user_ids, fn user_id ->
        assert user_id == user.user_id
        [user.user_id]
      end)

      times = length(messages)

      expect(Mailseek.MockUsers, :get_user, times, fn user_id ->
        assert user_id == user.user_id
        user
      end)

      expect(Mailseek.MockUsers, :get_primary_account, times, fn user ->
        user
      end)

      expect(Mailseek.MockNotifications, :notify, times, fn "emails:all",
                                                            {event, data, user_id} ->
        assert event == :email_updated
        assert %{message: _} = data
        assert user_id == user.user_id
        :ok
      end)

      message_ids = Enum.map(messages, & &1.message_id)

      conn =
        post(conn, ~p"/api/messages/unsubscribe", %{
          "message_ids" => message_ids,
          "user_id" => user.user_id
        })

      assert %{"message" => "Messages unsubscribed", "messages" => unsubscribed_messages} =
               json_response(conn, 200)

      assert length(unsubscribed_messages) == length(messages)
    end
  end

  describe "show/2" do
    test "loads a message", %{conn: conn, user: user, messages: [message | _]} do
      # Mock TokenManager.get_access_token/1
      expect(Mailseek.MockTokenManager, :get_access_token, fn user_id ->
        assert user_id == user.user_id
        {:ok, "mock_access_token"}
      end)

      # Mock Gmail.get_message_by_id/2
      expect(Mailseek.MockGmailClient, :get_message_by_id, fn token, message_id ->
        assert token == "mock_access_token"
        assert message_id == message.message_id

        {:ok,
         %{
           id: message.message_id,
           parts: [
             %{mime_type: "text/html", body: %{data: "PGgxPkhlbGxvIFdvcmxkPC9oMT4="}},
             %{mime_type: "text/plain", body: %{data: "SGVsbG8gV29ybGQ="}}
           ]
         }}
      end)

      # Mock Gmail.decode_base64/1 for HTML
      expect(Mailseek.MockGmailClient, :decode_base64, fn "PGgxPkhlbGxvIFdvcmxkPC9oMT4=" ->
        "<h1>Hello World</h1>"
      end)

      # Mock Gmail.decode_base64/1 for text
      expect(Mailseek.MockGmailClient, :decode_base64, fn "SGVsbG8gV29ybGQ=" ->
        "Hello World"
      end)

      conn = get(conn, ~p"/api/messages/#{message.message_id}?user_id=#{user.user_id}")

      assert %{"content" => content} = json_response(conn, 200)
      assert content["id"] == message.message_id
      assert content["html"] == "<h1>Hello World</h1>"
      assert content["text"] == "Hello World"
    end
  end
end
