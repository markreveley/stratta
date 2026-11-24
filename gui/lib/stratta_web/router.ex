defmodule StrattaWeb.Router do
  use StrattaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StrattaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", StrattaWeb do
    pipe_through :browser

    live_session :default do
      live "/", AppLive, :index
      live "/t/:thread_id", AppLive, :thread
      live "/providers", ProvidersLive, :index
    end
  end
end
