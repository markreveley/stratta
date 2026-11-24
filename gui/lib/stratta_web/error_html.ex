defmodule StrattaWeb.ErrorHTML do
  use StrattaWeb, :html
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
