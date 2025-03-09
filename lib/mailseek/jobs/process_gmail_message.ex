defmodule Mailseek.Jobs.ProcessGmailMessage do
  use Oban.Worker, queue: :gmail_message, max_attempts: 3

  alias Mailseek.Client.Gmail
  alias Mailseek.Gmail.TokenManager
  alias Mailseek.Gmail.Messages
  alias Mailseek.Jobs.CategorizeEmail
  alias Mailseek.Repo
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"provider" => "gmail", "message_id" => message_id, "user_id" => user_id}
      }) do
    do_perform(user_id, message_id)
  end

  defp do_perform(user_id, message_id) do
    {:ok, token} = TokenManager.get_access_token(user_id)
    {:ok, message = %{}} = Gmail.get_message_by_id(token, message_id)

    headers_map =
      message.headers
      |> Enum.map(fn header ->
        {header.name, header.value}
      end)
      |> Enum.into(%{})

    plain_text =
      message.parts
      |> Enum.find(fn part -> part.mime_type == "text/plain" end)
      |> case do
        nil -> ""
        part -> Gmail.decode_base64(part.body.data)
      end

    {:ok, %{from: from, to: to, subject: subject}} =
      Repo.transaction(fn ->
        {:ok, token} = TokenManager.get_access_token(user_id)

        # Archive message inside a transaction to ensure that if we can't archive it, we don't create a message in our db and will retry later
        {:ok, _} = Gmail.archive_message(token, message_id)

        Messages.create_message(%{
          message_id: message_id,
          user_id: user_id,
          subject: Map.fetch!(headers_map, "Subject"),
          from: Map.fetch!(headers_map, "From"),
          to: Map.fetch!(headers_map, "To"),
          status: "new"
        })
      end)

    CategorizeEmail.new(
      %{
        "provider" => "gmail",
        "email" => %{
          "from" => from,
          "to" => to,
          "subject" => subject,
          "body" => plain_text
        },
        "message_id" => message_id,
        "user_id" => user_id
      },
      meta: %{
        type: "categorize_gmail_message",
        user_id: user_id
      }
    )
    |> Oban.insert!()

    Logger.info("Processed message #{message_id} for user #{user_id}")

    :ok
  end
end
