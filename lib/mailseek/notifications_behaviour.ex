defmodule Mailseek.NotificationsBehaviour do
  @callback notify(String.t(), {atom(), map(), String.t()}) :: :ok
end
