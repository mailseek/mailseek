defmodule Mailseek.Jobs.InitiateGmailUserTest do
  use Mailseek.DataCase
  import Mox
  import Mailseek.Factory

  alias Mailseek.Jobs.InitiateGmailUser

  setup :verify_on_exit!

  describe "perform/1" do
    test "sets up Gmail watch and schedules fetch job" do
      user = insert(:user)

      # Mock TokenManager.get_access_token/1
      expect(Mailseek.MockTokenManager, :get_access_token, fn user_id ->
        assert user_id == user.user_id
        {:ok, "mock_access_token"}
      end)

      # Mock Gmail.set_watch/1
      expect(Mailseek.MockGmailClient, :set_watch, fn token ->
        assert token == "mock_access_token"
        {:ok, %{history_id: "new_history_id", expiration: 1_000_000_000}}
      end)

      job = %Oban.Job{args: %{"provider" => "gmail", "user_id" => user.user_id}}
      assert :ok = InitiateGmailUser.perform(job)

      expected_user_id = user.user_id

      assert [
               %{
                 meta: %{
                   "type" => "fetch_new_gmail_messages",
                   "user_id" => ^expected_user_id
                 }
               }
             ] = Repo.all(Oban.Job)

      # Verify user was updated with new history_id
      updated_user = Mailseek.Gmail.Users.get_user(user.user_id)
      assert updated_user.history_id == "new_history_id"
    end
  end
end
