defmodule MailseekWeb.MessageController do
  use MailseekWeb, :controller
  alias Mailseek.Gmail.Messages
  alias Mailseek.Gmail.Users

  def index(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "category_id" => "no_category"
      }) do
    %{} = Users.get_user(user_id)

    user_ids =
      user_id
      |> Users.get_connected_accounts()
      |> Enum.map(fn x -> x.user_id end)
      |> Enum.concat([user_id])

    json(conn, %{messages: Messages.list_messages(user_ids, [])})
  end

  def index(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "category_id" => category_id
      }) do
    %{} = Users.get_user(user_id)

    user_ids =
      user_id
      |> Users.get_connected_accounts()
      |> Enum.map(fn x -> x.user_id end)
      |> Enum.concat([user_id])

    category_ids = [category_id]
    json(conn, %{messages: Messages.list_messages(user_ids, category_ids)})
  end

  def delete(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "message_ids" => message_ids
      }) do
    msgs = Messages.delete_messages(user_id, message_ids)

    json(conn, %{message: "Messages deleted", messages: msgs})
  end

  def unsubscribe(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "message_ids" => message_ids
      }) do
    msgs = Messages.unsubscribe_messages(user_id, message_ids)

    json(conn, %{message: "Messages unsubscribed", messages: msgs})
  end

  def show(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "message_id" => message_id
      }) do
    msg = Messages.load_message(message_id, user_id)

    json(conn, %{content: msg})
  end
end
