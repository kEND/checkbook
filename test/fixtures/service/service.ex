defmodule MyApp.ExternalServices.Service do
  @callback send_reminder_email(map(), map()) :: :ok | :error
  def send_reminder_email(account, email_recipient),
    do: api_client().send_reminder_email(account, email_recipient)

  @callback send_submit_request(map(), map()) :: :ok | :error
  def send_submit_request(requestor, request),
    do: api_client().send_submit_request(requestor, request)

  defp some_private_function, do: send_reminder_email(:account, :email_recipient)

  defp api_client do
    Application.get_env(:MyApp, __MODULE__)[:api_client]
  end
end
