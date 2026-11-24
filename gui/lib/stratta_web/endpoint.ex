defmodule StrattaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :stratta_gui

  @session_options [store: :cookie, key: "_stratta_key", signing_salt: "stratta-cookie", same_site: "Lax"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static, at: "/", from: :stratta_gui, gzip: false, only: StrattaWeb.static_paths()
  plug Plug.Static, at: "/vendor/phoenix", from: {:phoenix, "priv/static"}, only: ~w(phoenix.min.js)
  plug Plug.Static, at: "/vendor/lv", from: {:phoenix_live_view, "priv/static"}, only: ~w(phoenix_live_view.min.js)

  plug Plug.RequestId
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug StrattaWeb.Router
end
