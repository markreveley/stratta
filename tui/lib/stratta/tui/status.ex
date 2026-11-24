defmodule Stratta.TUI.Status do
  @moduledoc """
  Reports thread state to whatever hosts the viewer.

    * **OSC 7501** program status reports: state, what it is blocked on, and
      one line of text. One-way; the terminal decides how to show it, and
      terminals that don't know the sequence ignore it.
    * **OSC 9;4** progress reports: a coarser busy / paused / error indicator
      that more terminals draw today.
    * **A status hook**: when `STRATTA_STATUS_HOOK` is set, that shell command
      runs on every change with `STRATTA_STATE`, `STRATTA_KIND`,
      `STRATTA_MESSAGE`, `STRATTA_THREAD` and `STRATTA_TITLE` in its
      environment. Use it for anything the sequences can't reach: a
      multiplexer's status line, a desktop notification, a phone push.

  A report is a map with `:state` (`"idle"`, `"working"`, `"done"`,
  `"blocked"`, `"error"`), and optionally `:kind`, `:msg` and `:title`.
  """

  @app "stratta"

  @doc """
  The report for one thread snapshot. `seen?` is false while a finished turn
  has not been looked at yet, which is what separates `done` from `idle`.
  """
  def report(snapshot, seen?) do
    items = snapshot["items"] || []

    report =
      case snapshot["status"] do
        status when status in ["running", "starting"] ->
          %{state: "working", msg: activity(items) || "Working"}

        "awaiting_approval" ->
          %{state: "blocked", kind: "permission", msg: pending_approval_title(items) || "Needs approval"}

        "failed" ->
          %{state: "error", msg: last_text(items, "notice") || "Session failed"}

        _idle ->
          case not seen? && last_of(items, "turn_end") do
            %{"status" => "completed"} -> %{state: "done", msg: first_line(last_text(items, "assistant")) || "Done"}
            %{"status" => "failed"} = turn -> %{state: "error", msg: turn["error"] || "Turn failed"}
            _ -> %{state: "idle"}
          end
      end

    Map.put(report, :title, get_in(snapshot, ["thread", "title"]))
  end

  @doc "The pending approval item of a snapshot, if any."
  def pending_approval(items), do: Enum.find(items, &(&1["kind"] == "approval" and &1["status"] == "pending"))

  defp pending_approval_title(items) do
    case pending_approval(items) do
      nil -> nil
      item -> item["title"]
    end
  end

  defp activity(items) do
    items
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{"kind" => "tool", "status" => status, "title" => title} when status in ["pending", "in_progress"] -> title
      _ -> nil
    end)
  end

  defp last_of(items, kind), do: items |> Enum.reverse() |> Enum.find(&(&1["kind"] == kind))

  defp last_text(items, kind) do
    case last_of(items, kind) do
      nil -> nil
      item -> item["text"]
    end
  end

  defp first_line(nil), do: nil
  defp first_line(text), do: text |> String.split("\n", parts: 2) |> hd()

  # -- escape sequences -------------------------------------------------------

  @doc "Everything to write when a report changes."
  def sequences(report, opts \\ []) do
    [osc7501(report), osc94(report), if(opts[:bell] && report.state == "blocked", do: "\a", else: [])]
  end

  @doc "An OSC 7501 report. `id` addresses a child record such as `thread/t123`."
  def osc7501(report, id \\ nil) do
    pairs =
      [
        {"state", report.state},
        {"id", id},
        {"kind", report.state == "blocked" && report[:kind]},
        {"app", @app},
        {"title", encode(report[:title], 60, 192)},
        {"msg", encode(report[:msg], 240, 2048)}
      ]
      |> Enum.filter(fn {_key, value} -> value not in [nil, false, ""] end)
      |> Enum.map_join(":", fn {key, value} -> key <> "=" <> value end)

    "\e]7501;" <> pairs <> "\e\\"
  end

  @doc "Removes a record (and its children). With no id, every record on this terminal."
  def clear(id \\ nil), do: "\e]7501;state=clear" <> if(id, do: ":id=" <> id, else: "") <> "\e\\"

  @doc "OSC 9;4 progress: indeterminate while working, paused when blocked, error, else cleared."
  def osc94(%{state: "working"}), do: "\e]9;4;3\a"
  def osc94(%{state: "blocked"}), do: "\e]9;4;4;100\a"
  def osc94(%{state: "error"}), do: "\e]9;4;2;100\a"
  def osc94(_report), do: "\e]9;4;0\a"

  def window_title(text), do: "\e]2;" <> clean(text || "stratta", 80) <> "\a"

  @doc "Runs `STRATTA_STATUS_HOOK`, if set, without waiting for it."
  def hook(report, thread_id) do
    case System.get_env("STRATTA_STATUS_HOOK") do
      hook when hook in [nil, ""] ->
        :ok

      hook ->
        env = [
          {"STRATTA_STATE", report.state},
          {"STRATTA_KIND", to_string(report[:kind] || "")},
          {"STRATTA_MESSAGE", clean(report[:msg] || "", 240)},
          {"STRATTA_TITLE", clean(report[:title] || "", 80)},
          {"STRATTA_THREAD", thread_id || ""}
        ]

        spawn(fn -> System.cmd("sh", ["-c", hook], env: env, stderr_to_stdout: true) end)
        :ok
    end
  end

  defp encode(nil, _chars, _bytes), do: nil

  defp encode(text, chars, bytes) do
    case text |> clean(chars) |> fit_bytes(bytes) do
      "" -> nil
      cleaned -> Base.encode64(cleaned)
    end
  end

  @doc """
  Makes text safe for a status line: one line, no control characters (the
  protocol discards a whole report that contains any), no bidi overrides.
  """
  def clean(text, max_chars) do
    text
    |> String.replace(~r/[\x{0000}-\x{001F}\x{007F}-\x{009F}]+/u, " ")
    |> String.replace(~r/[\x{202A}-\x{202E}\x{2066}-\x{2069}]/u, "")
    |> String.trim()
    |> String.slice(0, max_chars)
  end

  defp fit_bytes(text, max) when byte_size(text) <= max, do: text
  defp fit_bytes(text, max), do: text |> String.slice(0, String.length(text) - 1) |> fit_bytes(max)
end
