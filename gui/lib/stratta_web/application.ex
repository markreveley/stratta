defmodule StrattaWeb.Application do
  @moduledoc """
  The LiveView front end. The `:stratta` core application (started first, as a
  dependency) owns the threads and serves the control socket, so a running GUI
  is also the daemon the `stratta` terminal client talks to.
  """
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([StrattaWeb.Endpoint], strategy: :one_for_one, name: StrattaWeb.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    StrattaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
