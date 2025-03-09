defmodule MailseekWeb.ReportController do
  use MailseekWeb, :controller
  alias Mailseek.Reports

  def index(conn = %{assigns: %{current_user: %{}}}, %{
        "user_id" => user_id
      }) do
    json(conn, %{reports: Reports.list_reports(user_id)})
  end
end
