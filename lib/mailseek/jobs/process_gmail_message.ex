defmodule Mailseek.Jobs.ProcessGmailMessage do
  use Oban.Worker, queue: :gmail_message, max_attempts: 3

  alias Mailseek.Gmail.Messages
  alias Mailseek.Jobs.CategorizeEmail
  require Logger

  @gmail_client Application.compile_env(:mailseek, :gmail_client, Mailseek.Client.Gmail)
  @token_manager Application.compile_env(:mailseek, :token_manager, Mailseek.Gmail.TokenManager)

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"provider" => "gmail", "message_id" => message_id, "user_id" => user_id}
      }) do
    do_perform(user_id, message_id)
  end

  defp do_perform(user_id, message_id) do
    {:ok, token} = @token_manager.get_access_token(user_id)
    {:ok, message = %{}} = @gmail_client.get_message_by_id(token, message_id)

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
        part -> @gmail_client.decode_base64(part.body.data)
      end

    %{from: from, to: to, subject: subject} =
      Messages.create_message(%{
        message_id: message_id,
        user_id: user_id,
        subject: Map.fetch!(headers_map, "Subject"),
        from: Map.fetch!(headers_map, "From"),
        to: Map.fetch!(headers_map, "To"),
        sent_at: DateTime.from_unix!(message.sent_at_ms, :millisecond),
        status: "new"
      })

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
