# Add these factory functions to your existing factory.ex file
defmodule Mailseek.Factory do
  use ExMachina.Ecto, repo: Mailseek.Repo

  def user_factory do
    %Mailseek.User.Gmail{
      email: sequence(:email, &"user-#{&1}@example.com"),
      user_id: Ecto.UUID.generate(),
      access_token: "access_token",
      refresh_token: "refresh_token",
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
      history_id: "history_id"
    }
  end

  def message_factory do
    %Mailseek.Gmail.Message{
      message_id: sequence(:message_id, &"msg-#{&1}"),
      user_id: Ecto.UUID.generate(),
      subject: sequence(:subject, &"Subject #{&1}"),
      from: sequence(:from, &"sender-#{&1}@example.com"),
      status: "new",
      sent_at: DateTime.utc_now(),
      to: sequence(:to, &"recipient-#{&1}@example.com"),
      reason: "reason",
      summary: "summary",
      need_action: false,
    }
  end

  def category_factory do
    %Mailseek.User.UserCategory{
      name: sequence(:name, &"Category #{&1}"),
      user: build(:user),
      definition: sequence(:definition, &"Definition #{&1}")
    }
  end
end
