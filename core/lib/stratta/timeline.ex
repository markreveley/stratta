defmodule Stratta.Timeline do
  @moduledoc """
  Pure projection of `Jido.Harness.Event`s into a chat timeline.

  The thread server folds every session event through `apply_event/2`. The
  resulting items are plain string-keyed maps so they can be persisted as JSON
  and rendered directly by LiveView.

  Item kinds: `user`, `assistant`, `thinking`, `tool`, `plan`, `approval`,
  `turn_end`, `notice`.
  """

  alias Jido.Harness.Event

  defstruct items: [], tools: %{}, approvals: %{}, approval_seq: 0, cursor: 0, model: nil, usage: nil

  @type t :: %__MODULE__{}

  @doc "Builds a timeline from persisted items."
  def new(items \\ []) do
    items = Enum.map(items, &stringify/1)

    %__MODULE__{
      items: items,
      tools: index(items, "tool", "tool_call_id"),
      approvals: index(items, "approval", "request_id"),
      approval_seq: next_approval_seq(items)
    }
  end

  @doc """
  The letter that names a thread's n-th permission request: `a` to `z`, then
  `aa`, `ab` and so on. Letters are never reused within a thread, so a label
  always means the same request.
  """
  def approval_label(n) when n < 26, do: <<?a + n>>
  def approval_label(n), do: approval_label(div(n, 26) - 1) <> <<?a + rem(n, 26)>>

  defp next_approval_seq(items) do
    items
    |> Enum.flat_map(fn
      %{"kind" => "approval", "label" => label} when is_binary(label) -> [label_index(label) + 1]
      _ -> []
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp label_index(label),
    do: (label |> String.to_charlist() |> Enum.reduce(0, fn c, acc -> acc * 26 + (c - ?a + 1) end)) - 1

  @doc "Permission requests that are still waiting for an answer, oldest first."
  def pending_approvals(%__MODULE__{items: items}),
    do: Enum.filter(items, &(&1["kind"] == "approval" and &1["status"] == "pending"))

  defp index(items, kind, key) do
    for %{"kind" => ^kind} = item <- items, is_binary(item[key]), into: %{}, do: {item[key], item["id"]}
  end

  @doc "Appends a user message for an accepted turn."
  def add_user(%__MODULE__{} = tl, turn_id, text, extra \\ %{}) do
    push(tl, Map.merge(%{"kind" => "user", "turn_id" => turn_id, "text" => text}, stringify(extra)))
  end

  @doc "Appends a system notice (errors, configuration changes, git actions)."
  def add_notice(%__MODULE__{} = tl, level, text) do
    push(tl, %{"kind" => "notice", "level" => to_string(level), "text" => text})
  end

  @doc """
  Called when a thread is reloaded without a live session (e.g. after an app
  restart): pending approvals and unfinished tool calls can no longer be acted
  on, so mark them and note the interruption.
  """
  def close_dangling(%__MODULE__{items: items} = tl) do
    open_turns =
      items
      |> Enum.reduce(MapSet.new(), fn
        %{"kind" => "user", "turn_id" => t}, acc when is_binary(t) -> MapSet.put(acc, t)
        %{"kind" => "turn_end", "turn_id" => t}, acc -> MapSet.delete(acc, t)
        _, acc -> acc
      end)

    if MapSet.size(open_turns) == 0 and not Enum.any?(items, &(&1["status"] == "pending")) do
      tl
    else
      items =
        Enum.map(items, fn
          %{"kind" => "approval", "status" => "pending"} = i ->
            Map.put(i, "status", "expired")

          %{"kind" => "tool", "status" => s} = i when s in ["pending", "in_progress"] ->
            Map.put(i, "status", "interrupted")

          i ->
            i
        end)

      add_notice(
        %{tl | items: items},
        :warn,
        "The previous session ended before this turn finished. Send a message to continue."
      )
    end
  end

  @doc "Marks a pending approval resolved locally (the session will confirm it)."
  def resolve_approval(%__MODULE__{} = tl, request_id, decision) do
    update_indexed(tl, :approvals, request_id, &Map.put(&1, "status", to_string(decision)))
  end

  @doc "Folds one harness event into the timeline."
  def apply_event(%__MODULE__{} = tl, %Event{sequence: seq} = event) do
    tl = %{tl | cursor: max(tl.cursor, seq || 0)}
    reduce(tl, event.type, event)
  end

  # -- text streams -----------------------------------------------------------

  defp reduce(tl, :output_text_delta, %{payload: %{"text" => text}} = e),
    do: append_text(tl, "assistant", e.turn_id, text)

  defp reduce(tl, :thinking_delta, %{payload: %{"text" => text}} = e), do: append_text(tl, "thinking", e.turn_id, text)

  defp reduce(tl, :output_text_final, %{payload: %{"text" => text}} = e) when is_binary(text) do
    if Enum.any?(tl.items, &(&1["kind"] == "assistant" and &1["turn_id"] == e.turn_id)),
      do: tl,
      else: push(tl, %{"kind" => "assistant", "turn_id" => e.turn_id, "text" => text})
  end

  # -- tools ------------------------------------------------------------------

  defp reduce(tl, :tool_call, %{payload: p} = e) do
    tool_id = p["toolCallId"] || p["tool_call_id"] || "tool-#{e.sequence}"
    attrs = tool_attrs(p)

    if Map.has_key?(tl.tools, tool_id) do
      update_indexed(tl, :tools, tool_id, &merge_tool(&1, attrs))
    else
      item =
        Map.merge(
          %{"kind" => "tool", "turn_id" => e.turn_id, "tool_call_id" => tool_id, "output" => "", "diffs" => []},
          attrs
        )

      {tl, id} = push_with_id(tl, item)
      %{tl | tools: Map.put(tl.tools, tool_id, id)}
    end
  end

  defp reduce(tl, :tool_result, %{payload: p} = e) do
    tool_id = p["toolCallId"] || p["tool_call_id"]

    if tool_id && Map.has_key?(tl.tools, tool_id),
      do: update_indexed(tl, :tools, tool_id, &merge_tool(&1, tool_attrs(p))),
      else: reduce(tl, :tool_call, e)
  end

  defp reduce(tl, :command_output_delta, %{payload: p} = e) do
    text = p["text"] || p["output"] || ""

    case last_tool_for_turn(tl, e.turn_id) do
      nil -> append_text(tl, "assistant", e.turn_id, text)
      item_id -> update_item(tl, item_id, &Map.update(&1, "output", text, fn o -> o <> text end))
    end
  end

  defp reduce(tl, :file_change, %{payload: p} = e) do
    push(tl, %{
      "kind" => "tool",
      "turn_id" => e.turn_id,
      "title" => "File change",
      "tool_kind" => "edit",
      "status" => "completed",
      "output" => "",
      "diffs" => List.wrap(diff_from(p))
    })
  end

  # -- plan / usage -----------------------------------------------------------

  defp reduce(tl, :plan_updated, %{payload: p} = e) do
    entries = p["entries"] || []

    case Enum.find_index(tl.items, &(&1["kind"] == "plan" and &1["turn_id"] == e.turn_id)) do
      nil -> push(tl, %{"kind" => "plan", "turn_id" => e.turn_id, "entries" => entries})
      idx -> %{tl | items: List.update_at(tl.items, idx, &Map.put(&1, "entries", entries))}
    end
  end

  defp reduce(tl, :usage, %{payload: p}), do: %{tl | usage: p}

  # -- approvals --------------------------------------------------------------

  defp reduce(tl, :approval_requested, %{payload: p} = e) do
    tool = p["tool_call"] || %{}

    item = %{
      "kind" => "approval",
      "turn_id" => e.turn_id,
      "request_id" => e.request_id,
      "label" => approval_label(tl.approval_seq),
      "title" => tool["title"] || "Permission requested",
      "tool_kind" => tool["kind"],
      "options" => p["options"] || [],
      "diffs" => tool |> Map.get("content", []) |> List.wrap() |> Enum.flat_map(&List.wrap(diff_from(&1))),
      "status" => "pending"
    }

    {tl, id} = push_with_id(tl, item)
    %{tl | approvals: Map.put(tl.approvals, e.request_id, id), approval_seq: tl.approval_seq + 1}
  end

  defp reduce(tl, :approval_resolved, %{payload: p} = e) do
    status = if p["decision"] == "approve", do: "approved", else: "denied"
    update_indexed(tl, :approvals, e.request_id, &Map.merge(&1, %{"status" => status, "reason" => p["reason"]}))
  end

  # -- turn lifecycle ---------------------------------------------------------

  defp reduce(tl, type, e) when type in [:turn_completed, :turn_failed, :turn_interrupted] do
    status = type |> Atom.to_string() |> String.replace_prefix("turn_", "")

    tl
    |> expire_pending_approvals(e.turn_id)
    |> push(%{
      "kind" => "turn_end",
      "turn_id" => e.turn_id,
      "status" => status,
      "error" => e.payload["error"],
      "usage" => tl.usage
    })
    |> Map.put(:usage, nil)
  end

  defp reduce(tl, :session_failed, e),
    do: add_notice(tl, :error, "Session failed: #{e.payload["error"] || "unknown error"}")

  defp reduce(tl, :session_closed, _e), do: add_notice(tl, :info, "Session closed.")
  defp reduce(tl, :session_cancelled, _e), do: add_notice(tl, :info, "Session stopped.")

  # -- provider events --------------------------------------------------------

  defp reduce(tl, :provider_event, %{payload: %{"kind" => "replay_gap"}}),
    do: add_notice(tl, :warn, "Some earlier events were no longer retained by the harness.")

  defp reduce(tl, :provider_event, %{payload: %{"kind" => "acp_update", "update" => update}}) do
    case current_model(update["configOptions"]) do
      nil -> tl
      model -> %{tl | model: model}
    end
  end

  defp reduce(tl, :provider_event, %{payload: %{"kind" => "acp_session_configuration", "configuration" => conf}}) do
    case current_model(conf["configOptions"] || conf["config_options"]) do
      nil -> tl
      model -> %{tl | model: model}
    end
  end

  defp reduce(tl, _type, _event), do: tl

  # -- helpers ----------------------------------------------------------------

  defp current_model(options) when is_list(options) do
    Enum.find_value(options, fn
      %{"id" => "model", "currentValue" => v} -> v
      %{"category" => "model", "currentValue" => v} -> v
      _ -> nil
    end)
  end

  defp current_model(_), do: nil

  defp expire_pending_approvals(tl, turn_id) do
    items =
      Enum.map(tl.items, fn
        %{"kind" => "approval", "status" => "pending", "turn_id" => ^turn_id} = item ->
          Map.put(item, "status", "expired")

        item ->
          item
      end)

    %{tl | items: items}
  end

  defp tool_attrs(p) do
    content = List.wrap(p["content"])

    %{
      "title" => p["title"],
      "tool_kind" => p["kind"],
      "status" => p["status"],
      "input" => p["rawInput"] || p["raw_input"],
      "locations" => Enum.map(List.wrap(p["locations"]), & &1["path"]),
      "output" => content |> Enum.map(&content_text/1) |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join("\n"),
      "diffs" => Enum.flat_map(content, &List.wrap(diff_from(&1)))
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, [], ""] end)
    |> Map.new()
  end

  defp merge_tool(item, attrs) do
    Map.merge(item, attrs, fn
      "diffs", old, [] -> old
      _key, _old, new -> new
    end)
  end

  defp content_text(%{"type" => "content", "content" => %{"text" => text}}), do: text
  defp content_text(%{"type" => "text", "text" => text}), do: text
  defp content_text(%{"type" => "terminal", "terminalId" => id}), do: "[terminal #{id}]"
  defp content_text(_), do: nil

  defp diff_from(%{"type" => "diff", "path" => path} = d),
    do: %{"path" => path, "old" => d["oldText"] || "", "new" => d["newText"] || ""}

  defp diff_from(%{"path" => path, "diff" => diff}) when is_binary(diff), do: %{"path" => path, "patch" => diff}
  defp diff_from(_), do: nil

  defp last_tool_for_turn(tl, turn_id) do
    tl.items
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{"kind" => "tool", "turn_id" => ^turn_id, "id" => id} -> id
      _ -> nil
    end)
  end

  defp append_text(tl, kind, turn_id, text) when is_binary(text) do
    case List.last(tl.items) do
      %{"kind" => ^kind, "turn_id" => ^turn_id} ->
        %{tl | items: List.update_at(tl.items, -1, &Map.update!(&1, "text", fn t -> t <> text end))}

      _ ->
        push(tl, %{"kind" => kind, "turn_id" => turn_id, "text" => text})
    end
  end

  defp append_text(tl, _kind, _turn_id, _text), do: tl

  defp push(tl, item), do: tl |> push_with_id(item) |> elem(0)

  defp push_with_id(tl, item) do
    id = "i" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
    item = item |> Map.put("id", id) |> Map.put_new("at", DateTime.utc_now() |> DateTime.to_iso8601())
    {%{tl | items: tl.items ++ [item]}, id}
  end

  defp update_indexed(tl, index, key, fun) do
    case Map.fetch(Map.fetch!(tl, index), key) do
      {:ok, item_id} -> update_item(tl, item_id, fun)
      :error -> tl
    end
  end

  defp update_item(tl, item_id, fun) do
    %{
      tl
      | items:
          Enum.map(tl.items, fn
            %{"id" => ^item_id} = item -> fun.(item)
            item -> item
          end)
    }
  end

  defp stringify(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
end
