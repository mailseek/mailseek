defmodule Mailseek.Gmail.Messages do
  alias Mailseek.Gmail.Message
  alias Mailseek.Repo
  alias Mailseek.Client.Gmail
  alias Mailseek.Gmail.TokenManager

  import Ecto.Query

  def get_message(message_id) do
    Repo.get_by!(Message, message_id: message_id)
  end

  def load_message(message_id, user_id) do
    %{} = get_message_for_user(message_id, user_id)

    {:ok, token} = TokenManager.get_access_token(user_id)

    {:ok, %{id: id, parts: parts}} = Gmail.get_message_by_id(token, message_id)

    html =
      Enum.find(parts, fn part -> part.mime_type == "text/html" end)
      |> case do
        nil -> nil
        %{body: %{data: data}} -> Gmail.decode_base64(data)
      end

    text =
      Enum.find(parts, fn part -> part.mime_type == "text/plain" end)
      |> case do
        nil -> nil
        %{body: %{data: data}} -> Gmail.decode_base64(data)
      end


    %{
      id: id,
      html: html,
      text: text
    }
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert!()
  end

  def update_message(message, attrs) do
    message
    |> Message.update_changeset(attrs)
    |> Repo.update!()
  end

  def list_messages(user_ids, category_ids) do
    Repo.all(from m in Message, where: m.user_id in ^user_ids and m.category_id in ^category_ids, order_by: [desc: :inserted_at])
  end

  defp get_message_for_user(message_id, user_id) do
    Repo.get_by!(Message, message_id: message_id, user_id: user_id)
  end
end
