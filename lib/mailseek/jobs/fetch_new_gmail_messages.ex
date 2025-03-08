defmodule Mailseek.Jobs.FetchNewGmailMessages do
  use Oban.Worker, queue: :gmail_message, max_attempts: 5

  alias Mailseek.Repo
  alias Mailseek.Client.Gmail
  alias Mailseek.Gmail.TokenManager
  alias Mailseek.Gmail.Users
  alias Mailseek.Jobs.ProcessGmailMessage
  @interval 60

  require Logger

  @impl true
  def perform(%{args: %{"provider" => "gmail", "user_id" => _user_id} = args}) do
    result = do_perform(args)

    args
    |> new(schedule_in: @interval)
    |> Oban.insert!()

    result
  end

  defp do_perform(%{"provider" => "gmail", "user_id" => user_id}) do
    {:ok, token} = TokenManager.get_access_token(user_id)
    %{history_id: history_id} = Users.get_user(user_id)
    if is_nil(history_id) do
      raise "No history id found for user #{user_id}"
    end

    %{
      new_history_id: new_history_id,
      messages_added: messages_added
    } = Gmail.get_new_messages(token, history_id)

    dbg(messages_added)

    Repo.transaction(fn ->
      :ok = Enum.each(messages_added, fn message ->
        Logger.info("Adding message #{message.id} to user #{user_id}")
        ProcessGmailMessage.new(%{
          "provider" => "gmail",
          "user_id" => user_id,
          "message_id" => message.id
        })
        |> Oban.insert!()
      end)
    end)

    %{} =
      user_id
      |> Users.get_user()
      |> Users.update_user(%{history_id: new_history_id})

    :ok
  end
end
