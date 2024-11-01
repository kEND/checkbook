defmodule MyApp.ExternalServices.Service.SandboxClient do
  @behaviour MyApp.ExternalServices.Service

  def send_reminder_email(_sender_account, _email_recipient), do: :ok

  def send_submit_request(_requestor, _request), do: :ok
end
