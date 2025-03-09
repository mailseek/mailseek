defmodule Mailseek.Jobs.InitiateGmailUser do
  use Oban.Worker, queue: :gmail_message, max_attempts: 5

  alias Mailseek.Gmail.Users
  alias Mailseek.Jobs.FetchNewGmailMessages

  @gmail_client Application.compile_env(:mailseek, :gmail_client, Mailseek.Client.Gmail)
  @token_manager Application.compile_env(:mailseek, :token_manager, Mailseek.Gmail.TokenManager)

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider" => "gmail", "user_id" => user_id}}) do
    do_perform(user_id)
  end

  defp do_perform(user_id) do
    {:ok, token} = @token_manager.get_access_token(user_id)
    {:ok, %{history_id: history_id, expiration: expiration}} = @gmail_client.set_watch(token)

    %{} =
      user_id
      |> Users.get_user()
      |> Users.update_user(%{history_id: history_id})

    Logger.info(
      "Set watch for user #{user_id} with history_id #{history_id} and expiration #{expiration}"
    )

    FetchNewGmailMessages.new(
      %{
        "provider" => "gmail",
        "user_id" => user_id
      },
      meta: %{
        "type" => "fetch_new_gmail_messages",
        "user_id" => user_id
      }
    )
    |> Oban.insert!()

    :ok
  end
end
