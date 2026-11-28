defmodule Stratta.TUI.DiffView do
  @moduledoc """
  `stratta diff --watch`: a thread's changes against its base commit, kept
  current. It refetches whenever the thread finishes a tool call or a turn.
  """

  alias Stratta.TUI.{Client, Render}

  def init(sock, %{thread: ref}) do
    with {:ok, %{"thread" => id, "snapshot" => snapshot}} <- Client.call(sock, "subscribe", %{"thread" => ref}) do
      st = %{
        sock: sock,
        id: id,
        title: get_in(snapshot, ["thread", "title"]),
        sig: signature(snapshot),
        diff: nil,
        error: nil,
        top: 0,
        request: nil
      }

      {:ok, fetch(st)}
    end
  end

  defp fetch(st), do: %{st | request: Client.cast(st.sock, "thread.diff", %{"thread" => st.id})}

  defp signature(snapshot) do
    items = snapshot["items"] || []

    {snapshot["status"], Enum.count(items, &(&1["kind"] == "tool" and &1["status"] == "completed")),
     Enum.count(items, &(&1["kind"] == "turn_end"))}
  end

  def frame(%{"id" => id, "ok" => true, "result" => diff}, %{request: id} = st), do: %{st | diff: diff, error: nil}
  def frame(%{"id" => id, "ok" => false, "error" => error}, %{request: id} = st), do: %{st | error: error}

  def frame(%{"event" => "thread", "thread" => id, "snapshot" => snapshot}, %{id: id} = st) do
    st = %{st | title: get_in(snapshot, ["thread", "title"])}
    sig = signature(snapshot)
    if sig == st.sig, do: st, else: fetch(%{st | sig: sig})
  end

  def frame(_other, st), do: st

  def key(key, _st, _size) when key in [{:char, "q"}, :ctrl_c, :ctrl_d, :esc], do: {:halt, :quit}
  def key({:char, "r"}, st, _size), do: {:cont, fetch(st)}
  def key(key, st, size) when key in [:down, {:char, "j"}], do: {:cont, move(st, 1, size)}
  def key(key, st, size) when key in [:up, {:char, "k"}], do: {:cont, move(st, -1, size)}
  def key(:pgdn, st, {_w, h} = size), do: {:cont, move(st, h - 3, size)}
  def key(:pgup, st, {_w, h} = size), do: {:cont, move(st, 3 - h, size)}
  def key(:home, st, _size), do: {:cont, %{st | top: 0}}
  def key(:end, st, size), do: {:cont, move(st, 1_000_000, size)}
  def key(_key, st, _size), do: {:cont, st}

  defp move(st, by, {w, h}) do
    limit = max(length(body(st, w)) - max(h - 2, 1), 0)
    %{st | top: (st.top + by) |> max(0) |> min(limit)}
  end

  def render(st, {w, h}) do
    height = max(h - 2, 1)
    lines = body(st, w)
    top = min(st.top, max(length(lines) - height, 0))
    shown = lines |> Enum.drop(top) |> Enum.take(height)
    shown = shown ++ List.duplicate([], height - length(shown))
    {[header(st, w)] ++ shown ++ [[{:dim, Render.fit("↑/↓ pgup/pgdn scroll · r refresh · q quit", w)}]], nil}
  end

  defp header(st, w) do
    summary =
      case st.diff do
        %{"files" => files, "base" => base} ->
          adds = files |> Enum.map(& &1["additions"]) |> Enum.sum()
          dels = files |> Enum.map(& &1["deletions"]) |> Enum.sum()

          [
            {:dim, " · #{length(files)} files "},
            {:add, "+#{adds}"},
            {:dim, " "},
            {:del, "−#{dels}"},
            {:dim, " vs #{String.slice(base, 0, 7)}"}
          ]

        _ ->
          []
      end

    [{:bold, "Changes"}, {:dim, " · " <> Render.fit(st.title || "", max(w - 45, 10))}] ++ summary
  end

  defp body(st, w) do
    cond do
      st.error -> [[{:err, Render.fit(st.error, w)}]]
      st.diff == nil -> [[{:dim, "Loading…"}]]
      st.diff["files"] == [] -> [[{:dim, "No changes yet."}]]
      true -> Render.unified_diff(st.diff["text"], w)
    end
  end

  def status(_st), do: nil
  def emit(_old, _new, _st), do: []
  def leave(_st), do: []
end
