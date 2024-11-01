defmodule MyApp.ExternalServices.Service.Client do
  use Tesla

  alias MyApp.ExternalServices.Service
  alias Tesla.Middleware.BaseUrl
  alias Tesla.Middleware.BearerAuth
  alias Tesla.Middleware.Headers
  alias Tesla.Middleware.JSON
  alias Tesla.Middleware.Logger, as: TeslaLogger

  @behaviour Service

  def send_reminder_email(_sender_account, _email_recipient), do: :ok

  def send_submit_request(_requestor, _request), do: :ok

  def unused_function, do: :ok

  defp some_private_function, do: :ok
end
