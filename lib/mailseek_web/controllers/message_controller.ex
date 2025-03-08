defmodule MailseekWeb.MessageController do
  use MailseekWeb, :controller
  alias Mailseek.Gmail.Messages

  def index(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "category_id" => category_id
      }) do
    user_ids = [user_id]
    category_ids = [category_id]
    json(conn, %{messages: Messages.list_messages(user_ids, category_ids)})
  end
end
