defmodule Mailseek.Jobs.InitiateGmailUser do
  use Oban.Worker, queue: :gmail_message, max_attempts: 5

  alias Mailseek.Client.Gmail
  alias Mailseek.Gmail.TokenManager
  alias Mailseek.Gmail.Users
  alias Mailseek.Jobs.FetchNewGmailMessages

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider" => "gmail", "user_id" => user_id}}) do
    do_perform(user_id)
  end

  defp do_perform(user_id) do
    {:ok, token} = TokenManager.get_access_token(user_id)
    {:ok, %{history_id: history_id, expiration: expiration}} = Gmail.set_watch(token)
    %{} =
      user_id
      |> Users.get_user()
      |> Users.update_user(%{history_id: history_id})

    Logger.info("Set watch for user #{user_id} with history_id #{history_id} and expiration #{expiration}")

    FetchNewGmailMessages.new(%{
      "provider" => "gmail",
      "user_id" => user_id
    })
    |> Oban.insert!()

    :ok
  end
end
