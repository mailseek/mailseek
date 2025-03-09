defmodule Mailseek.GmailBehaviour do
  @callback initiate_user(String.t()) :: :ok | {:error, any()}
end
