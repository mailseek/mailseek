defmodule Mailseek.ReportsBehaviour do
  @callback list_reports(String.t()) :: [map()]
end
