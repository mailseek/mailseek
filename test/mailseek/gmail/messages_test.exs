defmodule Mailseek.Gmail.MessagesTest do
  use Mailseek.DataCase

  import Mox
  import Mailseek.Factory

  alias Mailseek.Gmail.Messages
  alias Mailseek.Gmail.Message
  alias Mailseek.Repo

  # Setup mocks
  setup :verify_on_exit!

  # Mock modules
  @gmail_client Mailseek.MockGmailClient
  @token_manager Mailseek.MockTokenManager
  @notifications Mailseek.MockNotifications

  setup do
    # Create a test user
    user = insert(:user)

    # Create some test messages
    messages = insert_list(3, :message, user_id: user.user_id)

    # Return context
    %{
      user: user,
      messages: messages
    }
  end

  describe "get_message/1" do
    test "returns the message with the given message_id", %{messages: [message | _]} do
      assert %Message{} = result = Messages.get_message(message.message_id)
      assert result.id == message.id
      assert result.message_id == message.message_id
    end

    test "raises if message doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Messages.get_message("non-existent-id")
      end
    end
  end

  describe "load_message/2" do
    test "loads message details from Gmail API", %{user: user, messages: [message | _]} do
      # Mock TokenManager.get_access_token/1
      expect(@token_manager, :get_access_token, fn user_id ->
        assert user_id == user.user_id
        {:ok, "mock_access_token"}
      end)

      # Mock Gmail.get_message_by_id/2
      expect(@gmail_client, :get_message_by_id, fn token, message_id ->
        assert token == "mock_access_token"
        assert message_id == message.message_id

        {:ok, %{
          id: message.message_id,
          parts: [
            %{mime_type: "text/html", body: %{data: "PGgxPkhlbGxvIFdvcmxkPC9oMT4="}},
            %{mime_type: "text/plain", body: %{data: "SGVsbG8gV29ybGQ="}}
          ]
        }}
      end)

      # Mock Gmail.decode_base64/1 for HTML
      expect(@gmail_client, :decode_base64, fn "PGgxPkhlbGxvIFdvcmxkPC9oMT4=" ->
        "<h1>Hello World</h1>"
      end)

      # Mock Gmail.decode_base64/1 for text
      expect(@gmail_client, :decode_base64, fn "SGVsbG8gV29ybGQ=" ->
        "Hello World"
      end)

      result = Messages.load_message(message.message_id, user.user_id)

      assert result == %{
        id: message.message_id,
        html: "<h1>Hello World</h1>",
        text: "Hello World"
      }
    end

    test "handles missing html or text parts", %{user: user, messages: [message | _]} do
      # Mock TokenManager.get_access_token/1
      expect(@token_manager, :get_access_token, fn user_id ->
        assert user_id == user.user_id
        {:ok, "mock_access_token"}
      end)

      # Mock Gmail.get_message_by_id/2 with only text part
      expect(@gmail_client, :get_message_by_id, fn _token, _message_id ->
        {:ok, %{
          id: message.message_id,
          parts: [
            %{mime_type: "text/plain", body: %{data: "SGVsbG8gV29ybGQ="}}
          ]
        }}
      end)

      # Mock Gmail.decode_base64/1 for text
      expect(@gmail_client, :decode_base64, fn "SGVsbG8gV29ybGQ=" ->
        "Hello World"
      end)

      result = Messages.load_message(message.message_id, user.user_id)

      assert result == %{
        id: message.message_id,
        html: nil,
        text: "Hello World"
      }
    end
  end

  describe "delete_messages/2" do
    test "marks messages as deleted and schedules deletion job", %{user: user, messages: messages} do
      message_ids = Enum.map(messages, & &1.message_id)

      times = length(messages)

      expect(Mailseek.MockUsers, :related_user_ids, fn user_id ->
        assert user_id == user.user_id
        [user.user_id]
      end)

      expect(Mailseek.MockUsers, :get_user, times, fn user_id ->
        assert user_id == user.user_id
        user
      end)

      expect(Mailseek.MockUsers, :get_primary_account, times, fn user ->
        assert user == user
        user
      end)

      expect(Mailseek.MockNotifications, :notify, times, fn "emails:all", {event, data, user_id} ->
        assert event == :email_updated
        assert %{message: %{}} = data
        assert user_id == user.user_id
        :ok
      end)

      result = Messages.delete_messages(user.user_id, message_ids)

      assert length(messages) == Repo.all(Oban.Job) |> length()

      assert length(result) == length(messages)

      for message <- result do
        assert message.status == "deleted"
      end
    end
  end

  describe "unsubscribe_messages/2" do
    test "marks messages for unsubscribing and schedules unsubscribe job", %{user: user, messages: messages} do
      message_ids = Enum.map(messages, & &1.message_id)

      times = length(messages)

      expect(Mailseek.MockUsers, :related_user_ids, fn user_id ->
        assert user_id == user.user_id
        [user.user_id]
      end)

      expect(Mailseek.MockUsers, :get_user, times, fn user_id ->
        assert user_id == user.user_id
        user
      end)

      expect(Mailseek.MockUsers, :get_primary_account, times, fn user ->
        assert user == user
        user
      end)
      expect(Mailseek.MockNotifications, :notify, times, fn "emails:all", {event, data, user_id} ->
        assert event == :email_updated
        assert %{message: %{}} = data
        assert user_id == user.user_id
        :ok
      end)

      result = Messages.unsubscribe_messages(user.user_id, message_ids)

      assert length(messages) == Repo.all(Oban.Job) |> length()

      assert length(result) == length(messages)

      # Verify messages are marked as unsubscribing
      for message_id <- message_ids do
        updated_message = Repo.get_by!(Message, message_id: message_id)
        assert updated_message.status == "unsubscribing"
      end
    end
  end

  describe "create_message/1" do
    test "creates a new message", %{user: user} do
      attrs = %{
        message_id: "new_message_id",
        user_id: user.user_id,
        subject: "Test Subject",
        from: "test@example.com",
        to: "test2@example.com",
        status: "new"
      }

      result = Messages.create_message(attrs)

      assert %Message{} = result
      assert result.message_id == attrs.message_id
      assert result.user_id == attrs.user_id
      assert result.subject == attrs.subject
      assert result.from == attrs.from
      assert result.status == attrs.status
    end

    test "updates existing message on conflict", %{user: user, messages: [message | _]} do
      attrs = %{
        message_id: message.message_id,
        user_id: user.user_id,
        status: "updated",
        summary: "test summary",
        to: "test2@example.com",
        from: "test@example.com",
        subject: "test subject"
      }

      result = Messages.create_message(attrs)

      assert %Message{} = result
      assert result.message_id == message.message_id
      assert result.user_id == user.user_id
      assert result.status == "updated"
      assert result.summary == "test summary"
    end
  end

  describe "update_message/2" do
    test "updates a message and sends notification", %{user: user, messages: [message | _]} do
      # Mock Users.get_user/1
      expect(Mailseek.MockUsers, :get_user, fn user_id ->
        assert user_id == user.user_id
        user
      end)

      # Mock Users.get_primary_account/1
      expect(Mailseek.MockUsers, :get_primary_account, fn user ->
        user
      end)

      # Mock Notifications.notify/3
      expect(@notifications, :notify, fn channel, {event, data, user_id} ->
        assert channel == "emails:all"
        assert event == :email_updated
        assert %{message: updated_message} = data
        assert updated_message.status == "updated"
        assert user_id == user.user_id
        :ok
      end)

      attrs = %{status: "updated", reason: "test update"}
      result = Messages.update_message(message, attrs)

      assert %Message{} = result
      assert result.status == "updated"
      assert result.reason == "test update"
    end
  end

  describe "list_messages/2" do
    test "lists messages for user with no category filter", %{user: user, messages: messages} do
      # Create some deleted messages that shouldn't be returned
      deleted_message = insert(:message, user_id: user.user_id, status: "deleted")

      # Create messages with categories
      category = insert(:category)
      categorized_message = insert(:message, user_id: user.user_id, category_id: category.id)

      result = Messages.list_messages([user.user_id], [])

      # Should return all non-deleted messages without categories
      assert length(result) == length(messages)

      # Verify deleted and categorized messages are not included
      refute Enum.any?(result, fn m -> m.id == deleted_message.id end)
      refute Enum.any?(result, fn m -> m.id == categorized_message.id end)
    end

    test "lists messages for user with category filter", %{user: user} do
      # Create categories
      category1 = insert(:category)
      category2 = insert(:category)

      # Create messages with categories
      message1 = insert(:message, user_id: user.user_id, category_id: category1.id)
      message2 = insert(:message, user_id: user.user_id, category_id: category1.id)
      message3 = insert(:message, user_id: user.user_id, category_id: category2.id)

      # Create a deleted message that shouldn't be returned
      deleted_message = insert(:message, user_id: user.user_id, category_id: category1.id, status: "deleted")

      # Test filtering by one category
      result1 = Messages.list_messages([user.user_id], [category1.id])
      assert length(result1) == 2
      assert Enum.all?(result1, fn m -> m.category_id == category1.id end)
      refute Enum.any?(result1, fn m -> m.id == deleted_message.id end)

      # Test filtering by multiple categories
      result2 = Messages.list_messages([user.user_id], [category1.id, category2.id])
      assert length(result2) == 3
      assert Enum.any?(result2, fn m -> m.id == message1.id end)
      assert Enum.any?(result2, fn m -> m.id == message2.id end)
      assert Enum.any?(result2, fn m -> m.id == message3.id end)
    end
  end
end
