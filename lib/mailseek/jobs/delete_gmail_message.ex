defmodule Mailseek.Jobs.DeleteGmailMessage do
  use Oban.Worker, queue: :gmail_message, max_attempts: 5
  alias Mailseek.Gmail.TokenManager
  alias Mailseek.Client.Gmail

  def perform(%Oban.Job{args: %{"message_id" => message_id, "user_id" => user_id}}) do
    {:ok, token} = TokenManager.get_access_token(user_id)

    :ok = Gmail.trash_message(token, message_id)

    :ok
  end
end
