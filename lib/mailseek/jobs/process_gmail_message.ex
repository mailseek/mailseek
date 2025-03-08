defmodule Mailseek.Jobs.ProcessGmailMessage do
  use Oban.Worker, queue: :gmail_message, max_attempts: 3

  alias Mailseek.Client.Gmail
  alias Mailseek.Gmail.TokenManager
  alias Mailseek.Gmail.Messages
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider" => "gmail", "message_id" => message_id, "user_id" => user_id}}) do
    do_perform(user_id, message_id)
  end

  defp do_perform(user_id, message_id) do
    {:ok, token} = TokenManager.get_access_token(user_id)
    message = %{} = Gmail.get_message_by_id(token, message_id)

    headers_map =
      message.headers
      |> Enum.map(fn header ->
        {header.name, header.value}
      end)
      |> Enum.into(%{})

    %{} = Messages.create_message(%{
      message_id: message_id,
      user_id: user_id,
      subject: Map.fetch!(headers_map, "Subject"),
      from: Map.fetch!(headers_map, "From"),
      to: Map.fetch!(headers_map, "To"),
      status: "new"
    })

    # TODO: Schedule AI processing here

    Logger.info("Processed message #{message_id} for user #{user_id}")

    :ok
  end
end
