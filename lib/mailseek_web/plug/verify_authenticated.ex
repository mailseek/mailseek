defmodule MailseekWeb.Plug.VerifyAuthenticated do
  import Plug.Conn
  alias MailseekWeb.AuthToken

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_token(token) do
      assign(conn, :current_user, claims)
    else
      _ -> unauthorized_response(conn)
    end
  end

  defp verify_token(token) do
    case AuthToken.verify_user_socket_token(token) do
      {:ok, %{} = data} ->
        {:ok, data}

      {:error, _} ->
        {:error, :unauthorized}
    end
  end

  defp unauthorized_response(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
