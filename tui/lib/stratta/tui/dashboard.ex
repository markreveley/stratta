defmodule Stratta.TUI.Dashboard do
  @moduledoc """
  `stratta watch`: the pane you leave open beside a shell.

  It shows every slotted thread, every permission request waiting on you
  (named the way `stratta approve` takes them), and the activity of the
  workspace's current thread. It follows the current thread: `stratta use 3`
  or `stratta new` in another pane switches what is shown here, and moving
  the selection here changes what commands in that pane act on.

  It also reports one status record per thread (`thread/<id>`) plus an
  aggregate, so a single pane can stand in for all running agents.
  """

  alias Stratta.TUI.{Client, Render, Status}

  @busy ["running", "starting", "awaiting_approval"]
  @max_records 60
  @two_columns_from 84

  def init(sock, %{workspace: workspace}) do
    with {:ok, %{"threads" => threads}} <- Client.call(sock, "subscribe", %{"all" => true}),
         {:ok, %{"thread" => current}} <- Client.call(sock, "subscribe", %{"current" => workspace}) do
      st = %{
        sock: sock,
        workspace: workspace,
        threads: threads,
        current: nil,
        snap: nil,
        rev: 0,
        request: nil,
        done: MapSet.new()
      }

      {:ok, focus(st, current)}
    end
  end

  # Follow another thread: stop hearing about the old one, ask for the new one.
  defp focus(%{current: id} = st, id), do: st

  defp focus(st, id) do
    if st.current, do: Client.cast(st.sock, "unsubscribe", %{"thread" => st.current})
    request = if id, do: Client.cast(st.sock, "subscribe", %{"thread" => id})
    %{st | current: id, snap: nil, rev: st.rev + 1, request: request, done: MapSet.delete(st.done, id)}
  end

  # -- daemon frames ----------------------------------------------------------

  def frame(%{"event" => "threads", "threads" => threads}, st) do
    before = Map.new(st.threads, &{&1["id"], &1["status"]})
    present = MapSet.new(threads, & &1["id"])

    finished =
      for t <- threads,
          before[t["id"]] in @busy,
          t["status"] == "idle",
          t["id"] != st.current,
          into: MapSet.new(),
          do: t["id"]

    done =
      Enum.reduce(threads, st.done |> MapSet.union(finished) |> MapSet.intersection(present), fn t, acc ->
        if t["status"] in @busy, do: MapSet.delete(acc, t["id"]), else: acc
      end)

    %{st | threads: threads, done: done}
  end

  def frame(%{"event" => "current", "workspace" => workspace, "thread" => id}, %{workspace: workspace} = st),
    do: focus(st, id)

  def frame(
        %{"id" => request, "ok" => true, "result" => %{"thread" => id, "snapshot" => snapshot}},
        %{request: request, current: id} = st
      ),
      do: %{st | snap: snapshot, rev: st.rev + 1}

  def frame(%{"event" => "thread", "thread" => id, "snapshot" => snapshot}, %{current: id} = st),
    do: %{st | snap: snapshot, rev: st.rev + 1}

  def frame(_other, st), do: st

  # -- keys -------------------------------------------------------------------

  def key(key, _st, _size) when key in [{:char, "q"}, :ctrl_c, :ctrl_d], do: {:halt, :quit}
  def key(key, st, _size) when key in [:down, {:char, "j"}], do: {:cont, step(st, 1)}
  def key(key, st, _size) when key in [:up, {:char, "k"}], do: {:cont, step(st, -1)}
  def key({:char, "c"}, st, _size), do: {:cont, %{st | done: MapSet.new()}}

  def key({:char, digit}, st, _size) when digit in ~w(1 2 3 4 5 6 7 8 9) do
    case Enum.find(st.threads, &(&1["slot"] == String.to_integer(digit))) do
      nil -> {:cont, st}
      thread -> {:cont, select(st, thread["id"])}
    end
  end

  def key(:enter, %{current: id}, _size) when is_binary(id), do: {:halt, {:open, id}}
  def key(_key, st, _size), do: {:cont, st}

  defp step(st, by) do
    slotted = slotted(st)

    case Enum.find_index(slotted, &(&1["id"] == st.current)) do
      _ when slotted == [] -> st
      nil -> select(st, hd(slotted)["id"])
      index -> select(st, Enum.at(slotted, (index + by) |> max(0) |> min(length(slotted) - 1))["id"])
    end
  end

  # Changing the selection changes the workspace's current thread for everyone.
  defp select(%{current: id} = st, id), do: st

  defp select(st, id) do
    Client.cast(st.sock, "current.set", %{"workspace" => st.workspace, "thread" => id})
    focus(st, id)
  end

  defp slotted(st), do: Enum.filter(st.threads, & &1["slot"])

  # -- rendering --------------------------------------------------------------

  def render(st, {w, h}) do
    threads = slotted(st)

    waiting =
      for t <- st.threads,
          request <- t["pending"] || [],
          do: {Render.request_name(t["slot"], request["label"]), request["title"]}

    top = top(st, threads, waiting, w, max(div(h, 2) - 1, 3))
    detail_height = max(h - length(top) - 3, 1)

    rows = [header(st, waiting)] ++ top ++ [separator(st, w)] ++ detail(st, w, detail_height) ++ [hints(w)]
    {rows, nil}
  end

  defp header(st, waiting) do
    working = Enum.count(st.threads, &(&1["status"] in ["running", "starting"]))

    [
      {:bold, "Stratta"},
      {:dim, " · #{length(st.threads)} threads · #{working} working"},
      {if(waiting == [], do: :dim, else: :warn), " · #{length(waiting)} waiting on you"}
    ]
  end

  # The thread list and the waiting requests: side by side when there is room,
  # stacked when there is not.
  defp top(st, threads, waiting, w, limit) do
    index = Enum.find_index(threads, &(&1["id"] == st.current)) || 0
    thread_rows = threads |> Enum.map(&thread_row(&1, st)) |> window(index, limit - 1)

    thread_rows =
      if thread_rows == [], do: [[{:dim, "  No threads yet. Start one: stratta new \"what to do\""}]], else: thread_rows

    waiting_rows =
      case waiting do
        [] -> [[{:dim, "  nothing"}]]
        _ -> for {name, title} <- waiting, do: [{:warn, "  " <> String.pad_trailing(name, 4)}, {:plain, title || ""}]
      end

    if w >= @two_columns_from do
      right_width = (w * 2) |> div(5) |> max(30) |> min(48)
      left_width = w - right_width - 2
      left = [[{:dim, "Threads"}] | thread_rows]
      right = [[{:dim, "Waiting on you"}] | Enum.take(waiting_rows, limit - 1)]

      for n <- 0..(max(length(left), length(right)) - 1) do
        Render.pad(Enum.at(left, n, []), left_width) ++
          [{:plain, "  "}] ++ Render.pad(Enum.at(right, n, []), right_width)
      end
    else
      extra = if waiting == [], do: [], else: [[{:dim, "Waiting on you"}] | Enum.take(waiting_rows, 3)]
      thread_rows ++ extra
    end
  end

  # At most `limit` rows, keeping the selected one in view.
  defp window(rows, selected, limit) do
    limit = max(limit, 1)
    first = (selected - limit + 1) |> max(0) |> min(max(length(rows) - limit, 0))
    rows |> Enum.drop(first) |> Enum.take(limit)
  end

  defp thread_row(thread, st) do
    selected? = thread["id"] == st.current
    {mark, style} = mark(thread, MapSet.member?(st.done, thread["id"]))

    [
      {if(selected?, do: :accent, else: :plain), if(selected?, do: "› ", else: "  ")},
      {if(selected?, do: :bold, else: :plain), String.pad_leading(to_string(thread["slot"]), 2) <> " "},
      {style, mark <> " "},
      {if(selected?, do: :bold, else: :plain), to_string(thread["title"])},
      {:dim, "  " <> to_string(thread["provider"])}
    ]
  end

  defp mark(thread, done?) do
    case thread["status"] do
      "awaiting_approval" -> {"⚠", :warn}
      s when s in ["running", "starting"] -> {"◐", :accent}
      "failed" -> {"✕", :err}
      _ when done? -> {"✓", :ok}
      "idle" -> {"●", :dim}
      _ -> {"○", :dim}
    end
  end

  defp separator(st, w) do
    case Enum.find(st.threads, &(&1["id"] == st.current)) do
      nil ->
        [{:dim, String.duplicate("─", w)}]

      thread ->
        title = "#{thread["slot"] || thread["id"]} · #{Render.fit(to_string(thread["title"]), max(w - 40, 10))}"
        meta = " · #{thread["provider"]} · #{status_text(thread["status"])} "
        fill = max(w - 3 - String.length(title) - String.length(meta), 0)
        [{:dim, "── "}, {:bold, title}, {:dim, meta <> String.duplicate("─", fill)}]
    end
  end

  defp detail(st, w, height) do
    lines =
      cond do
        st.current == nil -> [[{:dim, "No current thread. Choose one with ↑/↓ here, or `stratta use N` in a shell."}]]
        st.snap == nil -> [[{:dim, "Loading…"}]]
        (st.snap["items"] || []) == [] -> [[{:dim, "Nothing yet. Send it something: stratta send \"what to do\""}]]
        true -> timeline(st, w)
      end

    shown = Enum.take(lines, -height)
    shown ++ List.duplicate([], height - length(shown))
  end

  defp timeline(st, w) do
    key = {st.current, st.rev, w}

    case Process.get(:stratta_dashboard_lines) do
      {^key, lines} ->
        lines

      _ ->
        lines = Render.timeline(st.snap["items"] || [], w, get_in(st.snap, ["thread", "slot"]))
        Process.put(:stratta_dashboard_lines, {key, lines})
        lines
    end
  end

  defp hints(w), do: [{:dim, Render.fit("↑/↓ or 1-9 switch thread · enter open · c clear finished · q quit", w)}]

  defp status_text("running"), do: "working"
  defp status_text("starting"), do: "starting"
  defp status_text("awaiting_approval"), do: "needs approval"
  defp status_text("detached"), do: "not running"
  defp status_text(other), do: to_string(other)

  # -- status -----------------------------------------------------------------

  def status(st) do
    records =
      for thread <- Enum.take(st.threads, @max_records) do
        {thread["id"], report(thread, MapSet.member?(st.done, thread["id"]))}
      end

    %{root: aggregate(records), records: records}
  end

  defp report(thread, done?) do
    base = %{title: thread["title"]}

    case thread["status"] do
      "awaiting_approval" ->
        request = List.first(thread["pending"] || []) || %{}
        Map.merge(base, %{state: "blocked", kind: "permission", msg: request["title"] || "Needs approval"})

      s when s in ["running", "starting"] ->
        Map.merge(base, %{state: "working", msg: "Working"})

      "failed" ->
        Map.merge(base, %{state: "error", msg: "Session failed"})

      _ when done? ->
        Map.merge(base, %{state: "done", msg: "Finished"})

      _ ->
        Map.merge(base, %{state: "idle"})
    end
  end

  defp aggregate(records) do
    count = fn state -> Enum.count(records, fn {_id, r} -> r.state == state end) end

    cond do
      count.("blocked") > 0 ->
        %{state: "blocked", kind: "permission", msg: "#{count.("blocked")} waiting for approval", title: "Stratta"}

      count.("error") > 0 ->
        %{state: "error", msg: "#{count.("error")} failed", title: "Stratta"}

      count.("working") > 0 ->
        %{state: "working", msg: "#{count.("working")} working", title: "Stratta"}

      count.("done") > 0 ->
        %{state: "done", msg: "#{count.("done")} finished", title: "Stratta"}

      true ->
        %{state: "idle", title: "Stratta"}
    end
  end

  def emit(old, new, _st) do
    Status.hook(new.root, nil)

    gone =
      for {id, _} <- (old && old.records) || [],
          not List.keymember?(new.records, id, 0),
          do: Status.clear("thread/" <> id)

    children = for {id, report} <- new.records, do: Status.osc7501(report, "thread/" <> id)
    [Status.window_title("Stratta"), gone, children, Status.sequences(new.root)]
  end

  def leave(_st), do: [Status.clear(), Status.osc94(%{state: "idle"})]
end
