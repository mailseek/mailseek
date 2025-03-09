ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Mailseek.Repo, :manual)

Application.put_env(:mailseek, :gmail_client, Mailseek.MockGmailClient)
Application.put_env(:mailseek, :token_manager, Mailseek.MockTokenManager)
Application.put_env(:mailseek, :notifications, Mailseek.MockNotifications)
Application.put_env(:mailseek, :users, Mailseek.MockUsers)
