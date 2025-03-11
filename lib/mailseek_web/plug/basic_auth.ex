defmodule MailseekWeb.Plug.BasicAuth do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    username =
      Application.fetch_env!(:mailseek, :admin_username)

    password =
      Application.fetch_env!(:mailseek, :admin_password)

    case get_auth_header(conn) do
      {"Basic " <> encoded_credentials} ->
        case Base.decode64(encoded_credentials) do
          {:ok, credentials} ->
            [provided_username, provided_password] = String.split(credentials, ":", parts: 2)

            if provided_username == username && provided_password == password do
              conn
            else
              unauthorized(conn)
            end

          _ ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp get_auth_header(conn) do
    case get_req_header(conn, "authorization") do
      [header] -> {header}
      _ -> nil
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"Admin Area\"")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
