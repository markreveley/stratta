defmodule Stratta.TUI.RenderTest do
  use ExUnit.Case, async: true

  alias Stratta.TUI.Render

  defp text(lines), do: Enum.map(lines, &Render.plain/1)

  test "wraps on words, splits long words, keeps line breaks" do
    assert Render.wrap("the quick brown fox", 10) == ["the quick", "brown fox"]
    assert Render.wrap("abcdefghijkl", 5) == ["abcde", "fghij", "kl"]
    assert Render.wrap("one\n\ntwo", 10) == ["one", "", "two"]
  end

  test "renders a turn" do
    items = [
      %{"kind" => "user", "text" => "add a greeting"},
      %{
        "kind" => "plan",
        "entries" => [
          %{"status" => "completed", "content" => "Look"},
          %{"status" => "in_progress", "content" => "Edit"}
        ]
      },
      %{
        "kind" => "tool",
        "title" => "Edit a.txt",
        "tool_kind" => "edit",
        "status" => "completed",
        "diffs" => [%{"path" => "/w/a.txt", "old" => "hi", "new" => "hello"}]
      },
      %{
        "kind" => "approval",
        "title" => "Edit a.txt",
        "status" => "approved",
        "diffs" => [%{"path" => "/w/a.txt", "old" => "hi", "new" => "hello"}]
      },
      %{"kind" => "assistant", "text" => "Done."},
      %{"kind" => "turn_end", "status" => "completed", "usage" => %{"used" => 1200, "size" => 200_000}}
    ]

    assert text(Render.timeline(items, 60)) == [
             "› add a greeting",
             "Plan",
             "  ✓ Look",
             "  ◐ Edit",
             "✎ Edit a.txt  completed",
             "  a.txt",
             "  -hi",
             "  +hello",
             "⚠ Edit a.txt — approved",
             "",
             "Done.",
             "── Turn complete · 1.2k / 200.0k ctx"
           ]
  end

  test "a pending approval shows its diff; no line is wider than the terminal" do
    long = String.duplicate("word ", 60)

    items = [
      %{"kind" => "assistant", "text" => long},
      %{
        "kind" => "approval",
        "title" => "Edit",
        "status" => "pending",
        "diffs" => [%{"path" => "a", "old" => "", "new" => long}]
      },
      %{
        "kind" => "tool",
        "title" => "Run",
        "status" => "completed",
        "output" => Enum.map_join(1..9, "\n", &"line #{&1}")
      }
    ]

    lines = text(Render.timeline(items, 40))
    assert Enum.all?(lines, &(String.length(&1) <= 40))
    assert "⚠ Edit — waiting for you" in lines
    assert "  │ … 5 more lines" in lines
  end

  test "unified diffs drop git's bookkeeping lines" do
    diff = "diff --git a/x.ex b/x.ex\nindex 1..2 100644\n--- a/x.ex\n+++ b/x.ex\n@@ -1 +1 @@\n-old\n+new\n same\n"
    assert text(Render.unified_diff(diff, 80)) == ["▍ x.ex", "@@ -1 +1 @@", "-old", "+new", " same"]
  end

  test "a frame clears each row and positions the cursor" do
    frame = IO.iodata_to_binary(Render.frame([[{:bold, "title"}], [{:plain, "0123456789"}]], 5, {2, 3}))
    assert frame =~ "\e[1mtitle\e[0m\e[K\r\n01234\e[0m\e[K"
    assert frame =~ "\e[2;3H"
  end
end
