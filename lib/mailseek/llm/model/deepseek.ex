defmodule Mailseek.LLM.Model.DeepSeek do
  def api_key do
    Application.get_env(:langchain, :deepseek_api_key)
    |> case do
      nil -> raise "DeepSeek API key is not set"
      api_key_fn when is_function(api_key_fn, 0) -> api_key_fn.()
      api_key -> api_key
    end
  end

  def endpoint do
    "https://api.deepseek.com/v1/chat/completions"
  end
end
