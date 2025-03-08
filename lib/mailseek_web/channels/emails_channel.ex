defmodule MailseekWeb.EmailsChannel do
  use MailseekWeb, :channel
  alias MailseekWeb.AuthToken

  @impl true
  def join("emails:all", payload, socket) do
    dbg(payload)

    if authorized?(payload) do
      {:ok, %{categories: []}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:logs, category, logs}, socket) do
    broadcast(socket, "logs", %{category: category, logs: logs})
    {:noreply, socket}
  end

  defp authorized?(%{"token" => token}) do
    case AuthToken.verify_user_socket_token(token) |> dbg() do
      {:ok, _claims} -> true
      {:error, _} -> false
    end
  end

  defp authorized?(_), do: false
end
