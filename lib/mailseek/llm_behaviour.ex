defmodule Mailseek.LLMBehaviour do
  @callback process(map()) :: {:ok, map()} | {:error, any()}
end
