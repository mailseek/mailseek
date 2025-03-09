defmodule Mailseek.Gmail.Messages do
  alias Mailseek.Gmail.Message
  alias Mailseek.Repo
  alias Mailseek.Jobs.FindUnsubscribeLink
  alias Mailseek.Jobs.DeleteGmailMessage
  import Ecto.Query

  @gmail_client Application.compile_env(:mailseek, :gmail_client, Mailseek.Client.Gmail)
  @token_manager Application.compile_env(:mailseek, :token_manager, Mailseek.Gmail.TokenManager)
  @notifications Application.compile_env(:mailseek, :notifications, Mailseek.Notifications)
  @users Application.compile_env(:mailseek, :users, Mailseek.Gmail.Users)

  def get_message(message_id) do
    Repo.get_by!(Message, message_id: message_id)
  end

  def load_message(message_id, user_id) do
    %{} = get_message_for_user(message_id, user_id)

    {:ok, token} = @token_manager.get_access_token(user_id)

    {:ok, %{id: id, parts: parts}} = @gmail_client.get_message_by_id(token, message_id)

    html =
      Enum.find(parts, fn part -> part.mime_type == "text/html" end)
      |> case do
        nil -> nil
        %{body: %{data: data}} -> @gmail_client.decode_base64(data)
      end

    text =
      Enum.find(parts, fn part -> part.mime_type == "text/plain" end)
      |> case do
        nil -> nil
        %{body: %{data: data}} -> @gmail_client.decode_base64(data)
      end

    %{
      id: id,
      html: html,
      text: text
    }
  end

  def delete_messages(user_id, message_ids) do
    user_ids = @users.related_user_ids(user_id)

    msgs =
      Repo.all(
        from m in Message,
          where: m.message_id in ^message_ids and m.status != "deleted" and m.user_id in ^user_ids
      )

    msgs
    |> Enum.map(fn message ->
      msg =
        message
        |> update_message(%{status: "deleted"})

      DeleteGmailMessage.new(%{
        "user_id" => message.user_id,
        "provider" => "gmail",
        "message_id" => message.message_id
      })
      |> Oban.insert!()

      msg
    end)
  end

  def unsubscribe_messages(user_id, message_ids) do
    user_ids = @users.related_user_ids(user_id)

    msgs =
      Repo.all(
        from m in Message,
          where:
            m.message_id in ^message_ids and m.status != "unsubscribing" and
              m.user_id in ^user_ids
      )

    msgs
    |> Enum.map(fn message ->
      update_message(message, %{status: "unsubscribing"})

      FindUnsubscribeLink.new(%{
        "provider" => "gmail",
        "user_id" => message.user_id,
        "message_id" => message.message_id
      })
      |> Oban.insert!()

      message
    end)
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert!(
      on_conflict:
        {:replace, [:sent_at, :status, :reason, :model, :temperature, :need_action, :summary]},
      conflict_target: [:message_id, :user_id]
    )
  end

  def update_message(message, attrs) do
    msg =
      message
      |> Message.update_changeset(attrs)
      |> Repo.update!()

    primary_user =
      msg.user_id
      |> @users.get_user()
      |> @users.get_primary_account()

    @notifications.notify("emails:all", {
      :email_updated,
      %{
        message: msg
      },
      primary_user.user_id
    })

    msg
  end

  def list_messages(user_ids, []) do
    Repo.all(
      from m in Message,
        where: m.user_id in ^user_ids and is_nil(m.category_id) and m.status != "deleted",
        order_by: [desc_nulls_last: :sent_at]
    )
  end

  def list_messages(user_ids, category_ids) do
    Repo.all(
      from m in Message,
        where:
          m.user_id in ^user_ids and m.category_id in ^category_ids and m.status != "deleted",
        order_by: [desc_nulls_last: :sent_at]
    )
  end

  defp get_message_for_user(message_id, user_id) do
    Repo.get_by!(Message, message_id: message_id, user_id: user_id)
  end
end
