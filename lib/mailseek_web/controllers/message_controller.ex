defmodule MailseekWeb.MessageController do
  use MailseekWeb, :controller
  alias Mailseek.Gmail.Messages
  alias Mailseek.Gmail.Users
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

  def show(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "message_id" => message_id
      }) do
    msg = Messages.load_message(message_id, user_id)

    json(conn, %{content: msg})
  end
end
