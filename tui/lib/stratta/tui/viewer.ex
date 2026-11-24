defmodule Stratta.TUI.Viewer do
  @moduledoc """
  `stratta attach`: one thread, live. The timeline scrolls above a composer;
  approvals are answered with `y` / `n`; the hosting terminal is told what the
  agent is doing (see `Stratta.TUI.Status`).

  The viewer holds no agent state. Detaching leaves the thread running in the
  daemon, and any number of viewers (and the GUI) can watch the same thread.
  """

  alias Stratta.TUI.{Client, Render, Status}

  @chrome 4

  def init(sock, %{thread: ref} = arg) do
    with {:ok, %{"thread" => id, "snapshot" => snapshot}} <- Client.call(sock, "subscribe", %{"thread" => ref}) do
      {:ok,
       %{
         sock: sock,
         id: id,
         snap: snapshot,
         rev: 0,
         turns: turns(snapshot),
         input: "",
         scroll: 0,
         seen: true,
         flash: nil,
         bell: arg[:bell] == true
       }}
    end
  end

  # -- daemon frames ----------------------------------------------------------

  def frame(%{"event" => "thread", "thread" => id, "snapshot" => snapshot}, %{id: id} = st) do
    turns = turns(snapshot)
    %{st | snap: snapshot, rev: st.rev + 1, turns: turns, seen: st.seen and turns == st.turns}
  end

  def frame(%{"ok" => false, "error" => error}, st), do: %{st | flash: error}
  def frame(_other, st), do: st

  defp turns(snapshot), do: Enum.count(snapshot["items"] || [], &(&1["kind"] == "turn_end"))

  # -- keys -------------------------------------------------------------------

  def key(key, st, size), do: handle(key, %{st | seen: true, flash: nil}, size)

  defp handle({:char, c}, %{input: ""} = st, _size) when c in ["y", "Y", "n", "N"] do
    case Status.pending_approval(st.snap["items"] || []) do
      nil ->
        {:cont, %{st | input: c}}

      approval ->
        decision = if c in ["y", "Y"], do: "approve", else: "deny"

        Client.cast(st.sock, "thread.approve", %{
          "thread" => st.id,
          "request_id" => approval["request_id"],
          "decision" => decision
        })

        {:cont, st}
    end
  end

  defp handle({:char, c}, st, _size), do: {:cont, %{st | input: st.input <> c}}
  defp handle({:paste, text}, st, _size), do: {:cont, %{st | input: st.input <> String.replace(text, "\r", "\n")}}
  defp handle(:backspace, st, _size), do: {:cont, %{st | input: String.slice(st.input, 0..-2//1)}}
  defp handle(:ctrl_u, st, _size), do: {:cont, %{st | input: ""}}
  defp handle(:ctrl_w, st, _size), do: {:cont, %{st | input: String.replace(st.input, ~r/\S*\s*$/u, "", global: false)}}
  defp handle(:enter, st, _size), do: {:cont, submit(st, "auto")}
  defp handle(key, st, _size) when key in [:ctrl_s, :alt_enter], do: {:cont, submit(st, "steer")}

  defp handle(:esc, st, _size) do
    if busy?(st), do: Client.cast(st.sock, "thread.interrupt", %{"thread" => st.id})
    {:cont, st}
  end

  defp handle(:ctrl_c, st, _size) do
    cond do
      busy?(st) ->
        Client.cast(st.sock, "thread.interrupt", %{"thread" => st.id})
        {:cont, st}

      st.input != "" ->
        {:cont, %{st | input: ""}}

      true ->
        {:halt, :detached}
    end
  end

  defp handle(:ctrl_d, _st, _size), do: {:halt, :detached}
  defp handle(:up, st, size), do: {:cont, scroll(st, 3, size)}
  defp handle(:down, st, size), do: {:cont, scroll(st, -3, size)}
  defp handle(:pgup, st, {_w, h} = size), do: {:cont, scroll(st, max(h - @chrome - 1, 1), size)}
  defp handle(:pgdn, st, {_w, h} = size), do: {:cont, scroll(st, -max(h - @chrome - 1, 1), size)}
  defp handle(:home, st, size), do: {:cont, scroll(st, 1_000_000, size)}
  defp handle(:end, st, _size), do: {:cont, %{st | scroll: 0}}
  defp handle(_key, st, _size), do: {:cont, st}

  defp submit(st, mode) do
    case String.trim(st.input) do
      "" ->
        st

      text ->
        Client.cast(st.sock, "thread.send", %{"thread" => st.id, "text" => text, "mode" => mode})
        %{st | input: "", scroll: 0}
    end
  end

  defp scroll(st, by, {w, h}) do
    limit = max(length(lines(st, w)) - max(h - @chrome, 1), 0)
    %{st | scroll: (st.scroll + by) |> max(0) |> min(limit)}
  end

  defp busy?(st), do: st.snap["status"] in ["running", "starting", "awaiting_approval"]

  # -- rendering --------------------------------------------------------------

  def render(st, {w, h}) do
    body_height = max(h - @chrome, 1)
    lines = lines(st, w)
    hidden_below = min(st.scroll, max(length(lines) - body_height, 0))
    start = max(length(lines) - body_height - hidden_below, 0)
    body = lines |> Enum.drop(start) |> Enum.take(body_height)
    body = body ++ List.duplicate([], body_height - length(body))

    shown = st.input |> String.replace("\n", "⏎") |> tail(max(w - 3, 1))

    input =
      if st.input == "",
        do: [{:accent, "› "}, {:dim, if(busy?(st), do: "Queue a follow-up…", else: "Message the agent…")}],
        else: [{:accent, "› "}, {:plain, shown}]

    rows = [header(st, w)] ++ body ++ [status_row(st, hidden_below, w), input, hints(st, w)]
    {rows, {h - 1, 3 + String.length(shown)}}
  end

  # Wrapping a long thread on every repaint is wasted work while only the
  # composer changes, so the wrapped lines are kept per snapshot and width.
  defp lines(st, w) do
    case Process.get(:stratta_viewer_lines) do
      {key, lines} when key == {st.id, st.rev, w} ->
        lines

      _ ->
        lines = Render.timeline(st.snap["items"] || [], w)
        Process.put(:stratta_viewer_lines, {{st.id, st.rev, w}, lines})
        lines
    end
  end

  defp header(st, w) do
    thread = st.snap["thread"] || %{}
    branch = if thread["branch"], do: " · ⑂ " <> thread["branch"], else: ""

    [
      {dot_style(st.snap["status"]), "● "},
      {:bold, Render.fit(thread["title"] || "Thread", max(div(w, 2), 10))},
      {:dim, " · #{thread["provider"]}#{branch}"}
    ]
  end

  defp status_row(st, hidden_below, w) do
    approval = Status.pending_approval(st.snap["items"] || [])

    cond do
      st.flash ->
        [{:err, Render.fit(st.flash, w)}]

      approval ->
        [
          {:warn, "⚠ "},
          {:plain, Render.fit(approval["title"] || "Permission requested", max(w - 24, 10))},
          {:dim, "  "},
          {:bold, "y"},
          {:dim, " approve  "},
          {:bold, "n"},
          {:dim, " deny"}
        ]

      true ->
        parts =
          [
            status_text(st.snap["status"]),
            (st.snap["queued"] || 0) > 0 && "#{st.snap["queued"]} queued",
            st.snap["live_model"] || get_in(st.snap, ["thread", "model"]),
            hidden_below > 0 && "#{hidden_below} lines below (End to follow)"
          ]
          |> Enum.filter(&is_binary/1)

        [{:dim, Render.fit(Enum.join(parts, " · "), w)}]
    end
  end

  defp hints(st, w) do
    hints =
      if busy?(st),
        do: "enter queue · alt-enter steer · esc stop · pgup/pgdn scroll · ctrl-d detach",
        else: "enter send · pgup/pgdn scroll · ctrl-d detach"

    [{:dim, Render.fit(hints, w)}]
  end

  defp tail(text, width) do
    length = String.length(text)
    if length > width, do: String.slice(text, length - width, width), else: text
  end

  defp dot_style(status) when status in ["running", "starting"], do: :accent
  defp dot_style("awaiting_approval"), do: :warn
  defp dot_style("failed"), do: :err
  defp dot_style(_), do: :dim

  defp status_text("running"), do: "Working…"
  defp status_text("starting"), do: "Starting…"
  defp status_text("awaiting_approval"), do: "Needs approval"
  defp status_text("idle"), do: "Idle"
  defp status_text("detached"), do: "Not running; the agent starts with your first message"
  defp status_text("failed"), do: "Failed"
  defp status_text(other), do: String.capitalize(to_string(other))

  # -- status -----------------------------------------------------------------

  def status(st), do: Status.report(st.snap, st.seen)

  def emit(_old, report, st) do
    Status.hook(report, st.id)
    [Status.window_title(report[:title]), Status.sequences(report, bell: st.bell)]
  end

  # Once detached, this terminal no longer speaks for the thread.
  def leave(_st), do: [Status.clear(), Status.osc94(%{state: "idle"})]
end
