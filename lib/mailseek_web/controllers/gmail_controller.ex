defmodule MailseekWeb.GmailController do
  use MailseekWeb, :controller
  alias Mailseek.Gmail.Users
  alias Mailseek.Gmail

  def create_user(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id,
        "email" => email,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    user_id
    |> Users.upsert_user(%{
      user_id: user_id,
      email: email,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at
    })
    |> maybe_initiate_user()

    json(conn, %{})
  end

  def connect(conn = %{assigns: %{current_user: %{}}}, %{
        "from" => from_user_id,
        "to" => %{
          "user_id" => to_user_id,
          "email" => to_email,
          "access_token" => to_access_token,
          "refresh_token" => to_refresh_token,
          "expires_at" => to_expires_at
        }
      }) do
    %{} = from_user = Users.get_user(from_user_id)

    %{} =
      to_user_id
      |> Users.upsert_user(%{
        user_id: to_user_id,
        email: to_email,
        access_token: to_access_token,
        refresh_token: to_refresh_token,
        expires_at: to_expires_at
      })
      |> tap(fn {_, to_user} ->
        %{} =
          Users.connect_users(%{
            from_user_id: from_user.id,
            to_user_id: to_user.id,
            expires_at: DateTime.add(DateTime.utc_now(), 6, :day) |> DateTime.to_unix()
          })
      end)
      |> maybe_initiate_user()

    json(conn, %{})
  end

  defp maybe_initiate_user({:created, user = %{user_id: user_id}}) do
    Gmail.initiate_user(user_id)
    user
  end

  defp maybe_initiate_user({:updated, user}) do
    user
  end
end
