defmodule Mailseek.Jobs.ProcessGmailMessageTest do
  use Mailseek.DataCase
  import Mox
  import Mailseek.Factory

  alias Mailseek.Jobs.ProcessGmailMessage

  setup :verify_on_exit!

  describe "perform/1" do
    test "processes a Gmail message and schedules categorization" do
      user = insert(:user)
      message_id = "msg-123"

      # Mock TokenManager.get_access_token/1
      expect(Mailseek.MockTokenManager, :get_access_token, fn user_id ->
        assert user_id == user.user_id
        {:ok, "mock_access_token"}
      end)

      # Mock Gmail.get_message_by_id/2
      expect(Mailseek.MockGmailClient, :get_message_by_id, fn token, msg_id ->
        assert token == "mock_access_token"
        assert msg_id == message_id

        {:ok,
         %{
           id: message_id,
           sent_at_ms: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
           headers: [
             %{name: "Subject", value: "Test Subject"},
             %{name: "From", value: "sender@example.com"},
             %{name: "To", value: "recipient@example.com"}
           ],
           parts: [
             %{mime_type: "text/plain", body: %{data: "SGVsbG8gV29ybGQ="}}
           ]
         }}
      end)

      # Mock Gmail.decode_base64/1
      expect(Mailseek.MockGmailClient, :decode_base64, fn "SGVsbG8gV29ybGQ=" ->
        "Hello World"
      end)

      job = %Oban.Job{
        args: %{
          "provider" => "gmail",
          "user_id" => user.user_id,
          "message_id" => message_id
        }
      }

      assert :ok = ProcessGmailMessage.perform(job)

      expected_user_id = user.user_id
      expected_message_id = message_id

      # Schedule a categorization job
      assert [
               %{
                 meta: %{
                   "type" => "categorize_gmail_message"
                 },
                 args: %{
                   "provider" => "gmail",
                   "user_id" => ^expected_user_id,
                   "message_id" => ^expected_message_id
                 }
               }
             ] = Repo.all(Oban.Job)

      # Verify message was created in the database
      message = Mailseek.Gmail.Messages.get_message(message_id)
      assert message.message_id == message_id
      assert message.user_id == user.user_id
      assert message.subject == "Test Subject"
      assert message.from == "sender@example.com"
      assert message.to == "recipient@example.com"
      assert message.status == "new"
    end
  end
end
