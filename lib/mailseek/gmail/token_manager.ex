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

  def refresh_token(user_id) do
    GenServer.cast(__MODULE__, {:refresh_token, user_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:get_token, user_id}, _from, state) do
    max_expires_at = DateTime.add(DateTime.utc_now(), 300, :second) |> DateTime.to_unix(:second)

    case Map.get(state, user_id) do
      nil ->
        %{access_token: token, expires_at: expires_at, refresh_token: refresh_token} =
          Users.get_user(user_id)

        dbg("Fetched from db user #{user_id}")

        {:reply, {:ok, token},
         Map.put(state, user_id, %{
           access_token: token,
           expires_at: expires_at,
           is_refreshing: false,
           refresh_token: refresh_token
         })}

      %{access_token: token, expires_at: expires_at} when expires_at > max_expires_at ->
        # ✅ Token is still valid, return it
        {:reply, {:ok, token}, state}

      _ ->
        # ⏳ Token is expired or doesn't exist, trigger a refresh
        refresh_token(user_id)
        {:reply, {:error, :token_refreshing}, state}
    end
  end

  @impl true
  def handle_cast({:refresh_token, user_id}, state) do
    case Map.get(state, user_id) do
      nil ->
        %{} = params = handle_get_refresh_token(nil, user_id)

        send(self(), {:do_refresh, user_id})

        {:noreply,
         Map.put(state, user_id, %{
           access_token: params.access_token,
           expires_at: params.expires_at,
           is_refreshing: true,
           refresh_token: params.refresh_token
         })}

      %{is_refreshing: true} ->
        # If already refreshing, do nothing
        {:noreply, state}

      user = %{} ->
        updated_state = handle_get_refresh_token(user, user_id)

        # Send self a message to refresh token
        send(self(), {:do_refresh, user_id})

        {:noreply, Map.put(state, user_id, Map.put(updated_state, :is_refreshing, true))}
    end
  end

  defp handle_get_refresh_token(nil, user_id) do
    %{access_token: token, expires_at: expires_at, refresh_token: refresh_token} =
      Users.get_user(user_id)

    %{
      access_token: token,
      expires_at: expires_at,
      refresh_token: refresh_token
    }
  end

  defp handle_get_refresh_token(params = %{refresh_token: _refresh_token}, _user_id) do
    params
  end

  @impl true
  def handle_info({:do_refresh, user_id}, state) do
    case Map.get(state, user_id) do
      %{refresh_token: refresh_token} = user ->
        case fetch_new_token(refresh_token) do
          {:ok, new_token, expires_in} ->
            new_expiry = DateTime.add(DateTime.utc_now(), expires_in, :second)

            # Send self a message to update state
            send(self(), {:update_token, user_id, new_token, new_expiry})

            {:noreply, state}

          {:error, reason} ->
            IO.puts("Token refresh failed for #{user_id}: #{inspect(reason)}")

            # Unlock the user after failure
            updated_state = Map.put(state, user_id, Map.put(user, :is_refreshing, false))
            {:noreply, updated_state}
        end

      nil ->
        IO.puts("User #{user_id} not found in state, cannot refresh.")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:update_token, user_id, new_token, new_expiry}, state) do
    updated_user = %{
      access_token: new_token,
      expires_at: new_expiry |> DateTime.to_unix(:second),
      is_refreshing: false
    }

    updated_state = Map.put(state, user_id, updated_user)

    IO.puts("Token refreshed for #{user_id}")
    {:noreply, updated_state}
  end

  ## Helper Function

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
          |> dbg()

        {:ok, data["access_token"], data["expires_in"]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
