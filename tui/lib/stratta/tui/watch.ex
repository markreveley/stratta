defmodule Stratta.TUI.Watch do
  @moduledoc """
  `stratta watch`: every thread and its status in one view. It reports one
  status record per thread (`thread/<id>`) plus an aggregate, so a single
  pane can stand in for all running agents.
  """

  alias Stratta.TUI.{Client, Render, Status}

  @busy ["running", "starting", "awaiting_approval"]
  @max_records 60

  def init(sock, _arg) do
    with {:ok, %{"threads" => threads}} <- Client.call(sock, "subscribe", %{"all" => true}) do
      {:ok, %{sock: sock, threads: threads, selected: 0, done: MapSet.new()}}
    end
  end

  def frame(%{"event" => "threads", "threads" => threads}, st) do
    before = Map.new(st.threads, &{&1["id"], &1["status"]})

    finished =
      for t <- threads, before[t["id"]] in @busy, t["status"] == "idle", into: MapSet.new(), do: t["id"]

    present = MapSet.new(threads, & &1["id"])
    still_done = st.done |> MapSet.union(finished) |> MapSet.intersection(present)

    still_done =
      Enum.reduce(threads, still_done, fn t, acc ->
        if t["status"] in @busy, do: MapSet.delete(acc, t["id"]), else: acc
      end)

    %{st | threads: threads, done: still_done, selected: st.selected |> min(length(threads) - 1) |> max(0)}
  end

  def frame(_other, st), do: st

  def key(key, _st, _size) when key in [{:char, "q"}, :ctrl_c, :ctrl_d], do: {:halt, :quit}

  def key(key, st, _size) when key in [:down, {:char, "j"}],
    do: {:cont, %{st | selected: min(st.selected + 1, max(length(st.threads) - 1, 0))}}

  def key(key, st, _size) when key in [:up, {:char, "k"}], do: {:cont, %{st | selected: max(st.selected - 1, 0)}}
  def key({:char, "c"}, st, _size), do: {:cont, %{st | done: MapSet.new()}}

  def key(:enter, st, _size) do
    case Enum.at(st.threads, st.selected) do
      nil -> {:cont, st}
      thread -> {:halt, {:open, thread["id"]}}
    end
  end

  def key(_key, st, _size), do: {:cont, st}

  def render(st, {w, h}) do
    height = max(h - 2, 1)
    top = max(st.selected - height + 1, 0)

    rows =
      st.threads
      |> Enum.with_index()
      |> Enum.drop(top)
      |> Enum.take(height)
      |> Enum.map(fn {thread, index} -> row(thread, index == st.selected, MapSet.member?(st.done, thread["id"]), w) end)

    rows = if rows == [], do: [[{:dim, "No threads yet. Create one with: stratta new \"what to do\""}]], else: rows
    rows = rows ++ List.duplicate([], height - length(rows))
    waiting = Enum.count(st.threads, &(&1["status"] == "awaiting_approval"))
    working = Enum.count(st.threads, &(&1["status"] in ["running", "starting"]))

    header = [
      {:bold, "Stratta"},
      {:dim, " · #{length(st.threads)} threads · #{working} working"},
      {if(waiting > 0, do: :warn, else: :dim), " · #{waiting} waiting for you"}
    ]

    {[header] ++ rows ++ [[{:dim, Render.fit("↑/↓ select · enter open · c clear finished · q quit", w)}]], nil}
  end

  defp row(thread, selected?, done?, w) do
    {mark, style, label} =
      case thread["status"] do
        "awaiting_approval" -> {"⚠", :warn, "needs approval"}
        s when s in ["running", "starting"] -> {"◐", :accent, "working"}
        "failed" -> {"✕", :err, "failed"}
        _ when done? -> {"✓", :ok, "finished"}
        "idle" -> {"●", :dim, "idle"}
        _ -> {"○", :dim, "not running"}
      end

    title_width = max(w - 44, 12)
    title = thread["title"] |> to_string() |> Render.fit(title_width) |> String.pad_trailing(title_width)

    meta =
      "  #{String.pad_trailing(to_string(thread["provider"]), 10)} #{String.pad_trailing(Render.fit(to_string(thread["project"] || ""), 12), 12)} "

    [
      {if(selected?, do: :selected, else: :plain), if(selected?, do: "› ", else: "  ")},
      {style, mark <> " "},
      {if(selected?, do: :bold, else: :plain), title},
      {:dim, meta},
      {style, label}
    ]
  end

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
      "awaiting_approval" -> Map.merge(base, %{state: "blocked", kind: "permission", msg: "Needs approval"})
      s when s in ["running", "starting"] -> Map.merge(base, %{state: "working", msg: "Working"})
      "failed" -> Map.merge(base, %{state: "error", msg: "Session failed"})
      _ when done? -> Map.merge(base, %{state: "done", msg: "Finished"})
      _ -> Map.merge(base, %{state: "idle"})
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
