defmodule Mailseek.Gmail.Messages do
  alias Mailseek.Gmail.Message
  alias Mailseek.Repo

  import Ecto.Query

  def get_message(message_id) do
    Repo.get_by!(Message, message_id: message_id)
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
    Repo.all(from m in Message, where: m.user_id in ^user_ids and m.category_id in ^category_ids)
  end
end
