defmodule MailseekWeb.AuthToken do
  use Joken.Config

  def verify_user_socket_token(token) do
    Joken.verify_and_validate(%{alg: "HS256"}, token, Joken.Signer.create("HS256", secret()))
  end

  def sign(claims) do
    Joken.generate_and_sign(%{alg: "HS256"}, claims, Joken.Signer.create("HS256", secret()))
  end

  defp secret do
    Application.fetch_env!(:mailseek, :socket_secret)
  end
end
