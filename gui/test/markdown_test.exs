defmodule StrattaWeb.MarkdownTest do
  use ExUnit.Case, async: true

  defp md(text), do: text |> StrattaWeb.Components.markdown() |> Phoenix.HTML.safe_to_string()

  test "escapes HTML from agent output" do
    refute md("<script>alert(1)</script>") =~ "<script>"
  end

  test "renders code, bold, lists and fenced blocks" do
    html = md("Use `mix` **now**\n\n- a\n- b\n\n```elixir\nIO.puts(1 < 2)\n```\n")
    assert html =~ "<code>mix</code>"
    assert html =~ "<b>now</b>"
    assert html =~ "<li>a</li>"
    assert html =~ "IO.puts(1 &lt; 2)"
  end

  test "only allows http(s) links" do
    refute md("[x](javascript:alert(1))") =~ "href"
    assert md("[x](https://jido.run)") =~ ~s(href="https://jido.run")
  end
end
