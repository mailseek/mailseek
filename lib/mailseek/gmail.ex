defmodule Mailseek.Gmail do
  alias Mailseek.Jobs.InitiateGmailUser

  def initiate_user(user_id) do
    InitiateGmailUser.new(
      %{
        "provider" => "gmail",
        "user_id" => user_id
      },
      meta: %{
        "type" => "initiate_gmail_user",
        "user_id" => user_id
      }
    )
    |> Oban.insert!()
  end
end
