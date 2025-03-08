defmodule Mailseek.LLM do
  alias LangChain.Chains.LLMChain
  alias LangChain.Utils.ChainResult
  alias Mailseek.LLM.Chain.Categorize
  require Logger

  def process(user_context) do
    user_context
    |> Categorize.chain()
    |> LLMChain.run(mode: :while_needs_response)
    |> case do
      {:ok, updated_chain} ->
        updated_chain
        |> ChainResult.to_string()
        |> Categorize.build_response(user_context)

      {:error, _chain, %LangChain.LangChainError{message: message}} when is_binary(message) ->
        {:error, message}

      {:error, _chain, error} ->
        {:error, error}
    end
  end

  def process(_params, _user_context) do
    raise "params.role parameter is required for AI chain"
  end
end
