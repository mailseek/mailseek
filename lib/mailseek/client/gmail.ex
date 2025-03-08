defmodule Mailseek.Client.Gmail do
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection
  # Mailseek.Client.Gmail.list_messages()

  @topic "projects/mailseek/topics/mailseek-gmail-notifications"

  def set_watch(token) do
    conn = Connection.new(token)

    body = %{
      topicName: @topic,
      labelIds: ["INBOX"]  # Only watch new inbox messages
    }

    case Users.gmail_users_watch(conn, "me", body: body) do
      {:ok, %{historyId: history_id, expiration: expiration}} ->
        {:ok, %{history_id: history_id, expiration: expiration}}

      {:error, reason} ->
        IO.inspect(reason, label: "Error")
        dbg(reason)
        :error
    end
  end

  def get_message_by_id(token, id) do
    conn = Connection.new(token)

    {:ok, msg} = Users.gmail_users_messages_get(conn, "me", id)

    %{
      id: id,
      parts: msg.payload |> parse_message_part() |> Enum.reject(fn x -> x.body.size == 0 end),
      headers: msg.payload.headers |> Enum.filter(fn x -> x.name in ["Subject", "From", "To", "Date", "Return-Path"] end) |> Enum.map(fn x ->
        %{
          name: x.name,
          value: x.value
        }
      end)
    }
  end

  def get_new_messages(token, history_id) do
    conn = Connection.new(token)

    {:ok, %{history: history, historyId: new_history_id}} = Users.gmail_users_history_list(conn, "me", startHistoryId: history_id)

    %{
      new_history_id: new_history_id,
      messages_added: Enum.flat_map(history || [], fn
        %{messagesAdded: nil} -> []
        %{messagesAdded: messages} -> Enum.map(messages, fn x -> x.message end)
      end)
    }
  end

  def list_messages(token) do
    conn = Connection.new(token)

    {:ok, %{messages: messages}} = Users.gmail_users_messages_list(conn, "me")

    ids =
      messages
      |> Enum.take(10)
      |> Enum.map(fn x ->
        x.id
      end)
      |> tap(fn x_ids ->
        dbg(x_ids)
      end)

    ids
    |> Enum.take(2)
    |> Enum.map(fn id ->
      {:ok, msg} = Users.gmail_users_messages_get(conn, "me", id)
      dbg("Message id: #{id}")
      msg.payload
      |> parse_message_part()
    end)

    :ok
  end

  defp parse_message_part(%{body: %{data: _data} = body, parts: parts, mimeType: mime_type, partId: part_id}) do
    parts = parts || []
    dbg({"Parsed message part", part_id, mime_type, "has more included parts:", length(parts)})
    [%{
      body: body,
      mime_type: mime_type,
      part_id: part_id
    } | Enum.flat_map(parts, &parse_message_part/1)]
  end

  def decode_base64(encoded) do
    encoded
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64!()
  end
end
