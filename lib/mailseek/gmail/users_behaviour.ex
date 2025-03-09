defmodule Mailseek.Gmail.UsersBehaviour do
  @callback related_user_ids(String.t()) :: [String.t()]
  @callback get_user(String.t()) :: map()
  @callback get_primary_account(map()) :: map()
end
