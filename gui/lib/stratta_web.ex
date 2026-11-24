defmodule StrattaWeb do
  @moduledoc false

  def static_paths, do: ~w(assets favicon.svg robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller, only: [get_csrf_token: 0]
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import StrattaWeb.Components
      alias Phoenix.LiveView.JS

      use Phoenix.VerifiedRoutes,
        endpoint: StrattaWeb.Endpoint,
        router: StrattaWeb.Router,
        statics: StrattaWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
end
