defmodule Mailseek.Client.Gmail do
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection
  require Logger
  @topic "projects/mailseek/topics/mailseek-gmail-notifications"
  @behaviour Mailseek.Client.GmailBehaviour

  @impl true
  def set_watch(token) do
    conn = Connection.new(token)

    body = %{
      topicName: @topic,
      labelIds: ["INBOX"]
    }

    case Users.gmail_users_watch(conn, "me", body: body) do
      {:ok, %{historyId: history_id, expiration: expiration}} ->
        {:ok, %{history_id: history_id, expiration: expiration}}

      {:error, reason} ->
        IO.inspect(reason, label: "Error")
        :error
    end
  end

  @impl true
  def trash_message(token, message_id) do
    conn = Connection.new(token)

    case Users.gmail_users_messages_trash(conn, "me", message_id) do
      {:ok, _response} ->
        :ok

      {:error, %Tesla.Env{status: 404}} ->
        :ok

      {:error, reason} ->
        Logger.error("Error deleting message #{message_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def archive_message(token, message_id) do
    conn = Connection.new(token)

    body = %{
      # Moves email out of Inbox (archives it)
      removeLabelIds: ["INBOX"]
    }

    case Users.gmail_users_messages_modify(conn, "me", message_id, body: body) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        IO.inspect(reason, label: "Error")
        :error
    end
  end

  @impl true
  def get_message_by_id(token, id) do
    conn = Connection.new(token)

    case Users.gmail_users_messages_get(conn, "me", id) do
      {:ok, msg} ->
        {:ok,
         %{
           id: id,
           sent_at_ms: msg.internalDate |> String.to_integer(),
           parts:
             msg.payload |> parse_message_part() |> Enum.reject(fn x -> x.body.size == 0 end),
           headers:
             msg.payload.headers
             |> Enum.filter(fn x ->
               x.name in [
                 "Subject",
                 "From",
                 "To",
                 "Date",
                 "Return-Path",
                 "List-Unsubscribe",
                 "List-Unsubscribe-Post"
               ]
             end)
             |> Enum.map(fn x ->
               %{
                 name: x.name,
                 value: x.value
               }
             end)
         }}

      {:error, %Tesla.Env{status: 404}} ->
        {:error, :not_found}

      {:error, %Tesla.Env{status: 401}} ->
        {:error, :unauthorized}
    end
  end

  def get_new_messages(token, history_id) do
    conn = Connection.new(token)

    {:ok, %{history: history, historyId: new_history_id}} =
      Users.gmail_users_history_list(conn, "me", startHistoryId: history_id)

    %{
      new_history_id: new_history_id,
      messages_added:
        Enum.flat_map(history || [], fn
          %{messagesAdded: nil} ->
            []

          %{messagesAdded: messages} ->
            messages
            |> Enum.reject(fn x ->
              Enum.any?(["SENT", "DRAFT"], fn label -> label in x.message.labelIds end)
            end)
            |> Enum.map(fn x -> x.message end)
        end)
    }
  end

  defp parse_message_part(%{
         body: %{data: _data} = body,
         parts: parts,
         mimeType: mime_type,
         partId: part_id
       }) do
    parts = parts || []

    [
      %{
        body: body,
        mime_type: mime_type,
        part_id: part_id
      }
      | Enum.flat_map(parts, &parse_message_part/1)
    ]
  end

  @impl true
  def decode_base64(nil), do: nil

  def decode_base64(data) do
    data
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64!()
  end
end
