defmodule Mailseek.Client.Gmail do
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection

  @topic "projects/mailseek/topics/mailseek-gmail-notifications"

  def set_watch(token) do
    conn = Connection.new(token)

    body = %{
      topicName: @topic,
      # Only watch new inbox messages
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

  def get_message_by_id(token, id) do
    conn = Connection.new(token)

    case Users.gmail_users_messages_get(conn, "me", id) do
      {:ok, msg} ->
        {:ok,
         %{
           id: id,
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

  def list_messages(token) do
    conn = Connection.new(token)

    {:ok, %{messages: messages}} = Users.gmail_users_messages_list(conn, "me")

    messages
    |> Enum.take(10)
    |> Enum.map(fn x ->
      x.id
    end)
    |> Enum.take(2)
    |> Enum.map(fn id ->
      {:ok, msg} = Users.gmail_users_messages_get(conn, "me", id)

      msg.payload
      |> parse_message_part()
    end)

    :ok
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

  def decode_base64(nil), do: nil

  def decode_base64(encoded) do
    encoded
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64!()
  end
end
