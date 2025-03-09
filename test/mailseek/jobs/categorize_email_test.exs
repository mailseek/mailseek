defmodule Mailseek.Jobs.CategorizeEmailTest do
  use Mailseek.DataCase
  import Mox
  import Mailseek.Factory

  alias Mailseek.Jobs.CategorizeEmail

  setup :verify_on_exit!

  describe "perform/1" do
    test "categorizes an email message" do
      user = insert(:user)
      category = insert(:category, user: user, name: "Important")
      message = insert(:message, user_id: user.user_id)

      # Mock Users.get_user/1
      expect(Mailseek.MockUsers, :get_user, fn user_id ->
        assert user_id == user.user_id
        user
      end)

      # Mock Users.get_primary_account/1
      expect(Mailseek.MockUsers, :get_primary_account, fn user_struct ->
        assert user_struct.id == user.id
        user
      end)

      # Mock LLM.process/1
      expect(Mailseek.MockLLM, :process, fn params ->
        assert params.type == :categorize
        assert length(params.categories) == 1
        assert hd(params.categories).name == "Important"
        assert params.email.subject == message.subject
        assert params.email.from == message.from

        {:ok,
         %{
           response: %{
             "category" => "Important",
             "summary" => "Test summary",
             "need_action" => false,
             "reason" => "Test reason"
           }
         }}
      end)

      # Mock TokenManager.get_access_token/1
      expect(Mailseek.MockTokenManager, :get_access_token, fn user_id ->
        assert user_id == user.user_id
        {:ok, "mock_access_token"}
      end)

      # Mock Gmail.archive_message/2
      expect(Mailseek.MockGmailClient, :archive_message, fn token, msg_id ->
        assert token == "mock_access_token"
        assert msg_id == message.message_id
        {:ok, %{}}
      end)

      # Mock Notifications.notify/2
      expect(Mailseek.MockNotifications, :notify, fn "emails:all",
                                                     {event, data, notified_user_id} ->
        assert event == :email_updated
        assert data.message.id == message.id
        assert notified_user_id == user.user_id
        :ok
      end)

      # Mock Notifications.notify/2
      expect(Mailseek.MockNotifications, :notify, fn "emails:all",
                                                     {event, data, notified_user_id} ->
        assert event == :email_processed
        assert data.message.id == message.id
        assert notified_user_id == user.user_id
        :ok
      end)

      job = %Oban.Job{
        args: %{
          "provider" => "gmail",
          "message_id" => message.message_id,
          "user_id" => user.user_id,
          "email" => %{
            "from" => message.from,
            "to" => message.to,
            "subject" => message.subject,
            "body" => "Test email body"
          }
        }
      }

      assert :ok = CategorizeEmail.perform(job)

      # Verify message was updated
      updated_message = Mailseek.Gmail.Messages.get_message(message.message_id)
      assert updated_message.category_id == category.id
      assert updated_message.summary == "Test summary"
      assert updated_message.need_action == false
      assert updated_message.reason == "Test reason"
      assert updated_message.status == "processed"
    end
  end
end
