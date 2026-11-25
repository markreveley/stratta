defmodule Stratta.TUI.Render do
  @moduledoc """
  Pure rendering: thread items to styled lines, styled lines to a frame.

  A line is a list of `{style, text}` segments. Nothing here touches the
  terminal, so everything is testable as plain text (`plain/1`).
  """

  @sgr %{
    plain: "",
    bold: "\e[1m",
    dim: "\e[2m",
    accent: "\e[35m",
    user: "\e[1;36m",
    ok: "\e[32m",
    warn: "\e[33m",
    err: "\e[31m",
    add: "\e[32m",
    del: "\e[31m",
    hunk: "\e[36m",
    selected: "\e[7m"
  }

  @diff_preview 14
  @output_preview 4

  @type line :: [{atom, String.t()}]

  def plain(line), do: Enum.map_join(line, &elem(&1, 1))

  # -- timeline ---------------------------------------------------------------

  @doc """
  All items of a thread as lines no wider than `width`. With the thread's
  `slot`, permission requests are named the way commands refer to them (`2a`).
  """
  def timeline(items, width, slot \\ nil) do
    width = max(width, 20)

    items
    |> Enum.flat_map(&item(name_request(&1, slot), width))
    |> Enum.drop_while(&(&1 == []))
  end

  defp item(%{"kind" => "user"} = i, w) do
    queued = if i["mode"] == "queued", do: [[{:dim, "  queued"}]], else: []
    [[]] ++ prefixed(i["text"], w, :user, "› ", "  ") ++ queued
  end

  defp item(%{"kind" => "assistant"} = i, w), do: [[] | prefixed(i["text"], w, :plain, "", "")]

  defp item(%{"kind" => "thinking"} = i, w) do
    lines = wrap(String.trim(i["text"] || ""), w - 2)
    shown = lines |> Enum.take(2) |> Enum.map(&[{:dim, "∴ " <> &1}])
    if length(lines) > 2, do: shown ++ [[{:dim, "  …"}]], else: shown
  end

  defp item(%{"kind" => "plan"} = i, w) do
    entries =
      for e <- i["entries"] || [] do
        {mark, style} =
          case e["status"] do
            "completed" -> {"✓", :dim}
            "in_progress" -> {"◐", :accent}
            _ -> {"○", :plain}
          end

        [{style, fit("  #{mark} #{e["content"]}", w)}]
      end

    [[{:dim, "Plan"}] | entries]
  end

  defp item(%{"kind" => "tool"} = i, w) do
    status = i["status"] || ""

    head = [
      {:dim, tool_icon(i["tool_kind"]) <> " "},
      {:plain, i["title"] || "Tool call"},
      {status_style(status), "  " <> status}
    ]

    diffs = if status == "completed", do: i["diffs"] || [], else: []

    body =
      cond do
        diffs != [] -> Enum.flat_map(diffs, &diff_block(&1, w))
        (i["output"] || "") != "" -> output_block(i["output"], w)
        true -> []
      end

    [head | body]
  end

  defp item(%{"kind" => "approval"} = i, w) do
    name = if i["name"], do: [{:warn, i["name"] <> " "}], else: []

    head =
      [{:warn, "⚠ "}] ++
        name ++ [{:bold, i["title"] || "Permission requested"}, {:dim, " — " <> approval_text(i["status"])}]

    diffs = if i["status"] == "pending", do: i["diffs"] || [], else: []
    [head | Enum.flat_map(diffs, &diff_block(&1, w))]
  end

  defp item(%{"kind" => "turn_end"} = i, w) do
    {text, style} =
      case i["status"] do
        "completed" -> {"Turn complete", :dim}
        "interrupted" -> {"Interrupted", :warn}
        "failed" -> {"Turn failed" <> if(i["error"], do: ": #{i["error"]}", else: ""), :err}
        other -> {to_string(other), :dim}
      end

    [[{style, fit("── " <> text <> usage(i["usage"]), w)}]]
  end

  defp item(%{"kind" => "notice"} = i, w) do
    style =
      case i["level"] do
        "error" -> :err
        "success" -> :ok
        "warn" -> :warn
        _ -> :dim
      end

    prefixed(i["text"], w, style, "• ", "  ")
  end

  defp item(_other, _w), do: []

  defp name_request(%{"kind" => "approval", "label" => label} = item, slot) when is_binary(label),
    do: Map.put(item, "name", request_name(slot, label))

  defp name_request(item, _slot), do: item

  @doc "What a permission request is called: slot number then letter, or just the letter for an unslotted thread."
  def request_name(slot, label), do: "#{slot}#{label}"

  defp prefixed(text, w, style, first, rest) do
    (text || "")
    |> wrap(max(w - String.length(first), 10))
    |> Enum.with_index()
    |> Enum.map(fn {line, n} -> [{style, if(n == 0, do: first, else: rest) <> line}] end)
  end

  defp diff_block(diff, w) do
    lines = line_diff(diff)

    shown =
      for {type, text} <- Enum.take(lines, @diff_preview) do
        {style, sign} =
          case type do
            :add -> {:add, "+"}
            :del -> {:del, "-"}
            :gap -> {:dim, " "}
            _ -> {:plain, " "}
          end

        [{style, fit("  " <> sign <> text, w)}]
      end

    more = length(lines) - @diff_preview
    tail = if more > 0, do: [[{:dim, "  … #{more} more lines"}]], else: []
    [[{:dim, "  " <> Path.basename(diff["path"] || "")}]] ++ shown ++ tail
  end

  defp output_block(output, w) do
    lines = output |> String.trim_trailing() |> String.split("\n")
    shown = lines |> Enum.take(@output_preview) |> Enum.map(&[{:dim, fit("  │ " <> &1, w)}])
    more = length(lines) - @output_preview
    if more > 0, do: shown ++ [[{:dim, "  │ … #{more} more lines"}]], else: shown
  end

  defp tool_icon("edit"), do: "✎"
  defp tool_icon("search"), do: "⌕"
  defp tool_icon("execute"), do: "❯"
  defp tool_icon("delete"), do: "✕"
  defp tool_icon(_), do: "⚙"

  defp status_style("completed"), do: :ok
  defp status_style("failed"), do: :err
  defp status_style(s) when s in ["pending", "in_progress"], do: :accent
  defp status_style(_), do: :dim

  defp approval_text("pending"), do: "waiting for you"
  defp approval_text(other), do: to_string(other)

  defp usage(%{"used" => used, "size" => size}) when is_integer(used) and is_integer(size),
    do: " · #{short(used)} / #{short(size)} ctx"

  defp usage(%{"used" => used}) when is_integer(used), do: " · #{short(used)} tokens"
  defp usage(_), do: ""

  defp short(n) when n >= 1000, do: "#{Float.round(n / 1000, 1)}k"
  defp short(n), do: to_string(n)

  @doc "Line-level diff of a tool's `old`/`new` texts (or its ready-made `patch`), with long unchanged runs collapsed."
  def line_diff(%{"patch" => patch}) when is_binary(patch) do
    for line <- String.split(patch, "\n") do
      case line do
        "+" <> rest -> {:add, rest}
        "-" <> rest -> {:del, rest}
        rest -> {:ctx, rest}
      end
    end
  end

  def line_diff(%{"old" => old, "new" => new}) do
    String.split(old || "", "\n")
    |> List.myers_difference(String.split(new || "", "\n"))
    |> Enum.flat_map(fn
      {:eq, lines} when length(lines) > 6 ->
        Enum.map(Enum.take(lines, 2), &{:ctx, &1}) ++ [{:gap, "…"}] ++ Enum.map(Enum.take(lines, -2), &{:ctx, &1})

      {:eq, lines} ->
        Enum.map(lines, &{:ctx, &1})

      {:ins, lines} ->
        Enum.map(lines, &{:add, &1})

      {:del, lines} ->
        Enum.map(lines, &{:del, &1})
    end)
  end

  def line_diff(_), do: []

  # -- unified diff text ------------------------------------------------------

  @doc "A raw unified diff as styled lines, with git's bookkeeping lines dropped."
  def unified_diff(text, width) do
    text
    |> String.split("\n")
    |> Enum.flat_map(fn
      "diff --git " <> rest -> [[], [{:bold, fit("▍ " <> (rest |> String.split(" b/") |> List.last()), width)}]]
      "@@" <> _ = line -> [[{:hunk, fit(line, width)}]]
      "+++" <> _ -> []
      "---" <> _ -> []
      "+" <> _ = line -> [[{:add, fit(line, width)}]]
      "-" <> _ = line -> [[{:del, fit(line, width)}]]
      " " <> _ = line -> [[{:plain, fit(line, width)}]]
      "Binary files" <> _ = line -> [[{:dim, fit(line, width)}]]
      _bookkeeping -> []
    end)
    |> Enum.drop_while(&(&1 == []))
  end

  # -- text -------------------------------------------------------------------

  @doc "Word-wraps text to `width` columns, keeping its own line breaks."
  def wrap(text, width) do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_line(&1, max(width, 1)))
  end

  defp wrap_line(line, width) do
    if String.length(line) <= width do
      [line]
    else
      {lines, current} =
        line
        |> String.split(" ")
        |> Enum.flat_map(&chunk_word(&1, width))
        |> Enum.reduce({[], nil}, fn
          word, {lines, nil} ->
            {lines, word}

          word, {lines, current} ->
            if String.length(current) + 1 + String.length(word) <= width,
              do: {lines, current <> " " <> word},
              else: {[current | lines], word}
        end)

      Enum.reverse([current || "" | lines])
    end
  end

  defp chunk_word(word, width) do
    if String.length(word) <= width,
      do: [word],
      else: word |> String.graphemes() |> Enum.chunk_every(width) |> Enum.map(&Enum.join/1)
  end

  @doc "Cuts text to at most `width` columns."
  def fit(text, width) do
    text = String.replace(text, ~r/[\x{0000}-\x{001F}\x{007F}]/u, " ")
    if String.length(text) > width, do: String.slice(text, 0, max(width - 1, 0)) <> "…", else: text
  end

  # -- frame ------------------------------------------------------------------

  @doc """
  A full-screen repaint: every row cut to `width` and cleared to the end of the
  line, then the cursor placed at `cursor` (`{row, col}`, 1-based) or hidden.
  Wrapped in synchronized-output marks so terminals that support them never
  show a half-drawn frame.
  """
  def frame(rows, width, cursor) do
    body = rows |> Enum.map(&[ansi(&1, width), "\e[K"]) |> Enum.intersperse("\r\n")

    cursor =
      case cursor do
        {r, c} -> "\e[#{r};#{c}H\e[?25h"
        nil -> "\e[?25l"
      end

    ["\e[?2026h\e[?25l\e[H", body, "\e[J", cursor, "\e[?2026l"]
  end

  @doc "A line cut or padded with spaces to exactly `width` columns, for laying columns side by side."
  def pad(line, width) do
    {kept, left} =
      Enum.reduce(line, {[], width}, fn {style, text}, {kept, left} ->
        text = String.slice(text, 0, max(left, 0))
        {if(text == "", do: kept, else: [{style, text} | kept]), left - String.length(text)}
      end)

    Enum.reverse([{:plain, String.duplicate(" ", max(left, 0))} | kept])
  end

  @doc "One line with its styles applied, cut to `width` columns."
  def ansi(line, width) do
    {out, _left} =
      Enum.reduce(line, {[], width}, fn {style, text}, {out, left} ->
        if left <= 0 do
          {out, 0}
        else
          text = String.slice(text, 0, left)
          {[out, Map.fetch!(@sgr, style), text, "\e[0m"], left - String.length(text)}
        end
      end)

    out
  end
end
