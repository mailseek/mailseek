defmodule Mailseek.MessagesBehaviour do
  @callback load_message(String.t(), String.t()) :: map()
end
