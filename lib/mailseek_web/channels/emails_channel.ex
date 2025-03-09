defmodule MailseekWeb.EmailsChannel do
  use MailseekWeb, :channel
  alias MailseekWeb.AuthToken

  @impl true
  def join("emails:all", payload, socket) do
    case authorized?(payload) do
      {:ok, user_id} ->
        {:ok, %{}, assign(socket, :user_id, user_id)}

      :error ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(
        {:email_processed, payload, user_id},
        socket = %{assigns: %{user_id: socket_user_id}}
      )
      when socket_user_id == user_id do
    broadcast(socket, "email_processed", %{payload: payload, user_id: user_id})
    {:noreply, socket}
  end

  def handle_info(
        {:email_updated, payload, user_id},
        socket = %{assigns: %{user_id: socket_user_id}}
      )
      when socket_user_id == user_id do
    broadcast(socket, "email_updated", %{payload: payload, user_id: user_id})
    {:noreply, socket}
  end

  def handle_info(_x, socket) do
    {:noreply, socket}
  end

  defp authorized?(%{"token" => token}) do
    case AuthToken.verify_user_socket_token(token) do
      {:ok, %{"user_id" => user_id}} -> {:ok, user_id}
      {:error, _} -> :error
    end
  end

  defp authorized?(_), do: false
end
