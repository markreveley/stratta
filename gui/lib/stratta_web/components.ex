defmodule StrattaWeb.Components do
  @moduledoc "Function components shared by the LiveViews."
  use Phoenix.Component

  attr :status, :atom, required: true

  def status_dot(assigns) do
    ~H"""
    <span class={["dot", "dot-#{@status}"]} title={status_text(@status)}></span>
    """
  end

  def status_text(:running), do: "Working"
  def status_text(:awaiting_approval), do: "Needs approval"
  def status_text(:idle), do: "Idle"
  def status_text(:starting), do: "Starting"
  def status_text(:failed), do: "Failed"
  def status_text(:detached), do: "Not running"
  def status_text(other), do: other |> to_string() |> String.capitalize()

  attr :provider, :string, required: true

  def provider_badge(assigns) do
    ~H"""
    <span class={["pbadge", "p-#{@provider}"]}>{provider_initials(@provider)}</span>
    """
  end

  defp provider_initials("claude"), do: "CC"
  defp provider_initials("codex"), do: "CX"
  defp provider_initials("opencode"), do: "OC"
  defp provider_initials("gemini"), do: "GM"
  defp provider_initials("cursor"), do: "CU"
  defp provider_initials("antigravity"), do: "AG"
  defp provider_initials("demo"), do: "DM"
  defp provider_initials(p), do: p |> String.slice(0, 2) |> String.upcase()

  # -- timeline ---------------------------------------------------------------

  attr :item, :map, required: true
  attr :number, :any, default: nil, doc: "the thread's slot, used to name permission requests (2a)"

  def timeline_item(%{item: %{"kind" => "user"}} = assigns) do
    ~H"""
    <div class="msg msg-user">
      <div class="bubble">{@item["text"]}</div>
      <div :if={@item["mode"] == "queued"} class="meta">queued</div>
    </div>
    """
  end

  def timeline_item(%{item: %{"kind" => "assistant"}} = assigns) do
    ~H"""
    <div class="msg msg-agent">
      <div class="prose">{markdown(@item["text"])}</div>
    </div>
    """
  end

  def timeline_item(%{item: %{"kind" => "thinking"}} = assigns) do
    ~H"""
    <details class="thinking">
      <summary>Thinking</summary>
      <div class="thinking-body">{@item["text"]}</div>
    </details>
    """
  end

  def timeline_item(%{item: %{"kind" => "plan"}} = assigns) do
    ~H"""
    <div class="plan">
      <div class="plan-title">Plan</div>
      <ul>
        <li :for={e <- @item["entries"] || []} class={"plan-#{e["status"]}"}>
          <span class="plan-check">{plan_mark(e["status"])}</span> {e["content"]}
        </li>
      </ul>
    </div>
    """
  end

  def timeline_item(%{item: %{"kind" => "tool"}} = assigns) do
    ~H"""
    <details
      class={["tool", "tool-#{@item["status"]}"]}
      open={@item["status"] == "completed" and @item["diffs"] not in [nil, []]}
    >
      <summary>
        <span class="tool-kind">{tool_icon(@item["tool_kind"])}</span>
        <span class="tool-title">{@item["title"] || "Tool call"}</span>
        <span class="tool-status">{@item["status"]}</span>
      </summary>
      <div :if={@item["input"]} class="tool-io">
        <div class="label">Input</div>
        <pre>{pretty(@item["input"])}</pre>
      </div>
      <div :if={(@item["output"] || "") != ""} class="tool-io">
        <div class="label">Output</div>
        <pre>{String.slice(@item["output"], 0, 8000)}</pre>
      </div>
      <.inline_diff :for={d <- @item["diffs"] || []} diff={d} />
    </details>
    """
  end

  def timeline_item(%{item: %{"kind" => "approval"}} = assigns) do
    ~H"""
    <div class={["approval", "approval-#{@item["status"]}"]}>
      <div class="approval-head">
        <span class="approval-icon">⚠</span>
        <span>
          <span :if={@item["label"]} class="req" title="How to name this request to `stratta approve`">{@number}{@item[
            "label"
          ]}</span>
          <b>{@item["title"]}</b>
          <span class="muted">— {approval_text(@item["status"])}</span>
        </span>
      </div>
      <.inline_diff :for={d <- (@item["status"] == "pending" && @item["diffs"]) || []} diff={d} />
      <div :if={@item["status"] == "pending"} class="approval-actions">
        <button
          class="btn btn-primary"
          phx-click="approval"
          phx-value-request_id={@item["request_id"]}
          phx-value-decision="approve"
        >
          Approve
        </button>
        <button class="btn" phx-click="approval" phx-value-request_id={@item["request_id"]} phx-value-decision="deny">
          Deny
        </button>
      </div>
    </div>
    """
  end

  def timeline_item(%{item: %{"kind" => "turn_end"}} = assigns) do
    ~H"""
    <div class={["turn-end", "turn-#{@item["status"]}"]}>
      <span>{turn_text(@item["status"])}</span>
      <span :if={@item["error"]} class="err">{@item["error"]}</span>
      <span :if={usage = @item["usage"]} class="muted">{usage_text(usage)}</span>
    </div>
    """
  end

  def timeline_item(%{item: %{"kind" => "notice"}} = assigns) do
    ~H"""
    <div class={["notice", "notice-#{@item["level"]}"]}>{@item["text"]}</div>
    """
  end

  def timeline_item(assigns), do: ~H""

  attr :diff, :map, required: true

  def inline_diff(assigns) do
    assigns = assign(assigns, :lines, line_diff(assigns.diff))

    ~H"""
    <div class="idiff">
      <div class="idiff-path">{Path.basename(@diff["path"] || "")}</div>
      <div class="diff">
        <div :for={{t, l} <- @lines} class={"dl dl-#{t}"}>{diff_prefix(t)}{l}</div>
      </div>
    </div>
    """
  end

  # -- diff panel -------------------------------------------------------------

  attr :file, :map, required: true

  def diff_file(assigns) do
    ~H"""
    <details class="dfile" open={@file.additions + @file.deletions < 400}>
      <summary>
        <span class={"fstatus fs-#{@file.status}"}>{String.first(to_string(@file.status)) |> String.upcase()}</span>
        <span class="fpath">{@file.path}</span>
        <span class="fstat"><span class="add">+{@file.additions}</span> <span class="del">−{@file.deletions}</span></span>
      </summary>
      <div :if={@file.binary} class="muted pad">Binary file</div>
      <div :for={h <- @file.hunks} class="hunk">
        <div class="hunk-h">{h.header}</div>
        <div class="diff">
          <div :for={{t, l} <- h.lines} class={"dl dl-#{t}"}>{diff_prefix(t)}{l}</div>
        </div>
      </div>
    </details>
    """
  end

  # -- helpers ----------------------------------------------------------------

  defp plan_mark("completed"), do: "✓"
  defp plan_mark("in_progress"), do: "◐"
  defp plan_mark(_), do: "○"

  defp tool_icon("edit"), do: "✎"
  defp tool_icon("read"), do: "📄"
  defp tool_icon("search"), do: "⌕"
  defp tool_icon("execute"), do: "❯"
  defp tool_icon("fetch"), do: "⇣"
  defp tool_icon("delete"), do: "✕"
  defp tool_icon("think"), do: "…"
  defp tool_icon(_), do: "⚙"

  defp approval_text("pending"), do: "waiting for you"
  defp approval_text("approved"), do: "approved"
  defp approval_text("denied"), do: "denied"
  defp approval_text("expired"), do: "expired"
  defp approval_text(s), do: s

  defp turn_text("completed"), do: "Turn complete"
  defp turn_text("interrupted"), do: "Interrupted"
  defp turn_text("failed"), do: "Turn failed"
  defp turn_text(s), do: s

  defp usage_text(%{"used" => used, "size" => size}) when is_integer(used) and is_integer(size),
    do: "· #{format_int(used)} / #{format_int(size)} ctx"

  defp usage_text(%{"used" => used}) when is_integer(used), do: "· #{format_int(used)} tokens"
  defp usage_text(_), do: nil

  defp format_int(n) when n >= 1000, do: "#{Float.round(n / 1000, 1)}k"
  defp format_int(n), do: to_string(n)

  defp pretty(v) when is_binary(v), do: v
  defp pretty(v), do: Jason.encode!(v, pretty: true)

  defp diff_prefix(:add), do: "+"
  defp diff_prefix(:del), do: "-"
  defp diff_prefix(_), do: " "

  @doc false
  def line_diff(%{"patch" => patch}) when is_binary(patch) do
    patch
    |> String.split("\n")
    |> Enum.map(fn
      "+" <> l -> {:add, l}
      "-" <> l -> {:del, l}
      l -> {:ctx, l}
    end)
  end

  def line_diff(%{"old" => old, "new" => new}) do
    old_lines = String.split(old || "", "\n")
    new_lines = String.split(new || "", "\n")

    List.myers_difference(old_lines, new_lines)
    |> Enum.flat_map(fn
      {:eq, lines} -> trim_context(lines)
      {:ins, lines} -> Enum.map(lines, &{:add, &1})
      {:del, lines} -> Enum.map(lines, &{:del, &1})
    end)
  end

  def line_diff(_), do: []

  defp trim_context(lines) when length(lines) > 6,
    do: Enum.map(Enum.take(lines, 2), &{:ctx, &1}) ++ [{:gap, "…"}] ++ Enum.map(Enum.take(lines, -2), &{:ctx, &1})

  defp trim_context(lines), do: Enum.map(lines, &{:ctx, &1})

  @doc """
  Minimal, safe markdown: fenced code, inline code, bold, italics, links and
  paragraphs. Input is HTML-escaped first, so agent output can't inject markup.
  """
  def markdown(nil), do: ""

  def markdown(text) do
    text
    |> String.split(~r/^```[^\n]*\n/m)
    |> Enum.with_index()
    |> Enum.map(fn
      {chunk, i} when rem(i, 2) == 1 ->
        [code | rest] = String.split(chunk, ~r/^```\s*$/m, parts: 2)
        ["<pre class=\"code\"><code>", escape(code), "</code></pre>", inline_blocks(Enum.join(rest))]

      {chunk, _} ->
        inline_blocks(chunk)
    end)
    |> IO.iodata_to_binary()
    |> Phoenix.HTML.raw()
  end

  defp inline_blocks(text) do
    text
    |> String.split(~r/\n{2,}/, trim: true)
    |> Enum.map(fn para ->
      lines = String.split(para, "\n")

      if Enum.all?(lines, &Regex.match?(~r/^\s*([-*]|\d+\.)\s+/, &1)) do
        ["<ul>", Enum.map(lines, &["<li>", inline(Regex.replace(~r/^\s*([-*]|\d+\.)\s+/, &1, "")), "</li>"]), "</ul>"]
      else
        ["<p>", lines |> Enum.map(&inline/1) |> Enum.intersperse("<br>"), "</p>"]
      end
    end)
  end

  defp inline(line) do
    line
    |> escape()
    |> then(&Regex.replace(~r/`([^`]+)`/, &1, "<code>\\1</code>"))
    |> then(&Regex.replace(~r/\*\*([^*]+)\*\*/, &1, "<b>\\1</b>"))
    |> then(&Regex.replace(~r/(?<![\w*])\*([^*\n]+)\*(?![\w*])/, &1, "<i>\\1</i>"))
    |> then(
      &Regex.replace(
        ~r/\[([^\]]+)\]\((https?:\/\/[^)\s"]+)\)/,
        &1,
        "<a href=\"\\2\" target=\"_blank\" rel=\"noopener\">\\1</a>"
      )
    )
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
