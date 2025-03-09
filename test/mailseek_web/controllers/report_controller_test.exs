defmodule MailseekWeb.ReportControllerTest do
  use MailseekWeb.ConnCase
  import Mailseek.Factory

  setup %{conn: conn} do
    user = insert(:user)

    {:ok, token, _} = MailseekWeb.AuthToken.sign(%{"user_id" => user.user_id})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> assign(:current_user, user)

    %{conn: conn, user: user}
  end

  describe "index/2" do
    test "returns reports for a user", %{conn: conn, user: user} do
      insert(:report, user: user)
      insert(:report, user: user)

      conn = get(conn, ~p"/api/reports?user_id=#{user.user_id}")

      assert %{"reports" => reports} = json_response(conn, 200)
      assert length(reports) == 2
    end
  end
end
