defmodule Mailseek.Client.GmailBehaviour do
  @callback get_message_by_id(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  @callback decode_base64(String.t() | nil) :: String.t() | nil
  @callback archive_message(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  @callback trash_message(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  @callback set_watch(String.t()) :: {:ok, map()} | {:error, any()}
end
