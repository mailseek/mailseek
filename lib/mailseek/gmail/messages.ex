defmodule Mailseek.Gmail.Messages do
  alias Mailseek.Gmail.Message
  alias Mailseek.Repo

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
end
