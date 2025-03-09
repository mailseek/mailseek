defmodule Mailseek.Gmail.TokenManager do
  use GenServer
  alias Mailseek.Gmail.Users

  @google_token_url "https://oauth2.googleapis.com/token"

  ## Public API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_access_token(user_id) do
    GenServer.call(__MODULE__, {:get_token, user_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:get_token, user_id}, _from, state) do
    max_expires_at = DateTime.to_unix(DateTime.add(DateTime.utc_now(), 300, :second))

    case Users.get_user(user_id) do
      %{access_token: token, expires_at: expires_at} when expires_at > max_expires_at ->
        # ✅ Token is still valid, return it
        {:reply, {:ok, token}, state}

      %{refresh_token: refresh_token, expires_at: _expires_at} ->
        case do_sync_refresh_token(refresh_token) do
          {:ok, token, new_expires_at} ->
            %{} = Users.update_user(user_id, %{access_token: token, expires_at: new_expires_at})
            {:reply, {:ok, token}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  ## Helper Function

  defp do_sync_refresh_token(refresh_token) do
    case fetch_new_token(refresh_token) do
      {:ok, new_token, expires_in} ->
        new_expires_at =
          DateTime.add(DateTime.utc_now(), expires_in, :second) |> DateTime.to_unix(:second)

        {:ok, new_token, new_expires_at}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_new_token(refresh_token) do
    body = %{
      refresh_token: refresh_token,
      client_id: Application.fetch_env!(:mailseek, :google_client_id),
      client_secret: Application.fetch_env!(:mailseek, :google_client_secret),
      grant_type: "refresh_token"
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(@google_token_url, URI.encode_query(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        data =
          Jason.decode!(body)

        {:ok, data["access_token"], data["expires_in"]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
