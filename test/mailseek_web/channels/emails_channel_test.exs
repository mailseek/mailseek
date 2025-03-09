defmodule MailseekWeb.EmailsChannelTest do
  use MailseekWeb.ChannelCase
  import Mailseek.Factory
  alias MailseekWeb.AuthToken

  setup do
    # Create a test user
    user = insert(:user)

    # Return context
    %{user: user}
  end

  describe "join" do
    test "joins the channel successfully with user_id", %{user: user} do
      {:ok, token, _} =
        AuthToken.sign(%{
          "user_id" => user.user_id
        })

      {:ok, _, socket} =
        MailseekWeb.UserSocket
        |> socket("user_id", %{user_id: user.user_id})
        |> subscribe_and_join(MailseekWeb.EmailsChannel, "emails:all", %{
          "token" => token
        })

      assert socket.assigns.user_id == user.user_id
    end

    test "rejects join without proper authentication" do
      assert {:error, %{reason: "unauthorized"}} =
               MailseekWeb.UserSocket
               |> socket("user_id", %{})
               |> subscribe_and_join(MailseekWeb.EmailsChannel, "emails:all", %{
                 "token" => "invalid_token"
               })
    end
  end
end
