defmodule Mailseek.Gmail.TokenManagerBehaviour do
  @callback get_access_token(String.t()) :: {:ok, String.t()} | {:error, any()}
end
