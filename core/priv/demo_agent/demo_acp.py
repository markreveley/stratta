#!/usr/bin/env python3
"""
Stratta demo ACP agent.

A tiny, dependency-free Agent Client Protocol agent that speaks JSON-RPC over
stdio. It exists so Stratta works out of the box with no coding-agent CLI
installed: it streams thinking, a plan, tool calls, asks for permission before
"editing", writes a real file in the session cwd (so the diff panel has
something to show), and streams a final answer.

It is NOT an LLM. It is a scripted fixture that exercises every UI path.
"""
import json
import os
import queue
import sys
import threading
import time
import uuid

OUT = threading.Lock()
PENDING = {}            # our outbound request id -> queue for the response
PENDING_LOCK = threading.Lock()
STATE = {
    "session_id": None,
    "cwd": os.getcwd(),
    "model": "demo-fast",
    "cancel": threading.Event(),
    "turn": None,         # (request_id, steer_queue)
    "next_id": 1000,
}
MODELS = [
    {"value": "demo-fast", "name": "Demo Fast"},
    {"value": "demo-thorough", "name": "Demo Thorough"},
]


def send(msg):
    line = json.dumps(msg, separators=(",", ":")) + "\n"
    with OUT:
        sys.stdout.write(line)
        sys.stdout.flush()


def update(update_kind, **fields):
    payload = {"sessionUpdate": update_kind}
    payload.update(fields)
    send({"jsonrpc": "2.0", "method": "session/update",
          "params": {"sessionId": STATE["session_id"], "update": payload}})


def request(method, params, timeout=None):
    with PENDING_LOCK:
        STATE["next_id"] += 1
        rid = STATE["next_id"]
        q = queue.Queue()
        PENDING[rid] = q
    send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
    try:
        return q.get(timeout=timeout)
    except queue.Empty:
        return None
    finally:
        with PENDING_LOCK:
            PENDING.pop(rid, None)


def pause(seconds):
    """Sleep in small steps so cancellation is responsive. Returns False if cancelled."""
    end = time.time() + seconds
    while time.time() < end:
        if STATE["cancel"].is_set():
            return False
        time.sleep(0.02)
    return not STATE["cancel"].is_set()


def stream_text(kind, text, delay):
    for word in text.split(" "):
        if not pause(delay):
            return False
        update(kind, content={"type": "text", "text": word + " "})
    return True


def list_files(cwd, limit=12):
    found = []
    for root, dirs, files in os.walk(cwd):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("node_modules", "_build", "deps")]
        for name in [f for f in files if not f.startswith(".")]:
            found.append(os.path.relpath(os.path.join(root, name), cwd))
            if len(found) >= limit:
                return found
    return found


def run_turn(request_id, prompt_text, steer_q):
    slow = 0.06 if STATE["model"] == "demo-thorough" else 0.025
    cancel = STATE["cancel"]
    wants_edit = any(w in prompt_text.lower() for w in ("edit", "write", "create", "fix", "add ", "change", "implement", "update"))

    def finish(reason="end_turn"):
        update("usage_update", used=len(prompt_text) * 3 + 420, size=200000)
        send({"jsonrpc": "2.0", "id": request_id, "result": {"stopReason": reason}})

    if not stream_text("agent_thought_chunk",
                       f"The user asked: \"{prompt_text[:80]}\". Let me look at the workspace first, then decide what to do.",
                       slow / 2):
        return finish("cancelled")

    steps = [{"content": "Inspect the workspace", "priority": "high", "status": "in_progress"},
             {"content": "Make the requested change" if wants_edit else "Draft an answer", "priority": "medium", "status": "pending"},
             {"content": "Summarize", "priority": "low", "status": "pending"}]
    update("plan", entries=steps)

    tool_id = "tc-" + uuid.uuid4().hex[:8]
    update("tool_call", toolCallId=tool_id, title="List files in workspace", kind="search", status="in_progress",
           rawInput={"path": STATE["cwd"]})
    if not pause(0.4):
        return finish("cancelled")
    files = list_files(STATE["cwd"])
    update("tool_call_update", toolCallId=tool_id, status="completed",
           content=[{"type": "content", "content": {"type": "text", "text": "\n".join(files) or "(empty)"}}])

    steps[0]["status"] = "completed"
    steps[1]["status"] = "in_progress"
    update("plan", entries=steps)

    # Steering: anything the host injected mid-turn is acknowledged here.
    injected = []
    while not steer_q.empty():
        injected.append(steer_q.get())

    if wants_edit:
        target = os.path.join(STATE["cwd"], "STRATTA_DEMO.md")
        old = open(target).read() if os.path.exists(target) else ""
        stamp = time.strftime("%Y-%m-%d %H:%M:%S")
        new = old + f"\n## {stamp}\n\nRequest: {prompt_text.strip()}\n\nDone by the Stratta demo agent ({STATE['model']}).\n"
        edit_id = "tc-" + uuid.uuid4().hex[:8]
        tool_call = {"toolCallId": edit_id, "title": "Edit STRATTA_DEMO.md", "kind": "edit", "status": "pending",
                     "locations": [{"path": target}],
                     "content": [{"type": "diff", "path": target, "oldText": old, "newText": new}]}
        update("tool_call", **tool_call)
        resp = request("session/request_permission", {
            "sessionId": STATE["session_id"],
            "toolCall": tool_call,
            "options": [
                {"optionId": "allow-once", "name": "Allow once", "kind": "allow_once"},
                {"optionId": "allow-always", "name": "Always allow", "kind": "allow_always"},
                {"optionId": "reject-once", "name": "Reject", "kind": "reject_once"},
            ],
        })
        if cancel.is_set():
            return finish("cancelled")
        outcome = ((resp or {}).get("result") or {}).get("outcome") or {}
        approved = outcome.get("outcome") == "selected" and outcome.get("optionId", "").startswith("allow")
        if approved:
            with open(target, "w") as fh:
                fh.write(new)
            update("tool_call_update", toolCallId=edit_id, status="completed",
                   content=[{"type": "diff", "path": target, "oldText": old, "newText": new}])
            summary = f"I updated `STRATTA_DEMO.md` in the workspace with a note about your request. Open the diff panel to review it, then commit when you're happy."
        else:
            update("tool_call_update", toolCallId=edit_id, status="failed",
                   content=[{"type": "content", "content": {"type": "text", "text": "Permission denied by user"}}])
            summary = "You declined the edit, so I left the workspace untouched."
    else:
        summary = (f"I'm the Stratta demo agent running on `{STATE['model']}`. I found {len(files)} file(s) in the workspace. "
                   "Ask me to *edit* or *create* something to see approvals, file diffs, and the commit flow.")

    if injected:
        summary += " (Steering noted: " + "; ".join(injected) + ")"

    steps[1]["status"] = "completed"
    steps[2]["status"] = "completed"
    update("plan", entries=steps)

    if not stream_text("agent_message_chunk", summary, slow):
        return finish("cancelled")
    finish()


def handle(msg):
    method = msg.get("method")
    rid = msg.get("id")
    params = msg.get("params") or {}

    if method is None and rid is not None:
        with PENDING_LOCK:
            q = PENDING.get(rid)
        if q:
            q.put(msg)
        return

    if method == "initialize":
        send({"jsonrpc": "2.0", "id": rid, "result": {
            "protocolVersion": 1,
            "agentCapabilities": {
                "loadSession": True,
                "sessionCapabilities": {"close": {}, "fork": {}},
                "promptCapabilities": {"image": False, "embeddedContext": True},
            },
            "agentInfo": {"name": "stratta-demo", "version": "0.1.0"},
            "authMethods": [],
            "_meta": {"steering": {"supported": True}},
        }})
    elif method in ("session/new", "session/load", "session/fork"):
        STATE["cwd"] = params.get("cwd") or STATE["cwd"]
        if method == "session/load":
            STATE["session_id"] = params.get("sessionId")
        else:
            STATE["session_id"] = "demo-" + uuid.uuid4().hex[:12]
        send({"jsonrpc": "2.0", "id": rid, "result": {
            "sessionId": STATE["session_id"],
            "configOptions": [{"id": "model", "name": "Model", "category": "model", "type": "select",
                               "currentValue": STATE["model"], "options": MODELS}],
        }})
    elif method == "session/prompt":
        text = " ".join(b.get("text", "") for b in params.get("prompt", []) if isinstance(b, dict))
        STATE["cancel"].clear()
        steer_q = queue.Queue()
        STATE["turn"] = (rid, steer_q)

        def worker():
            try:
                run_turn(rid, text, steer_q)
            finally:
                STATE["turn"] = None

        threading.Thread(target=worker, daemon=True).start()
    elif method == "_session/steering":
        turn = STATE["turn"]
        if turn is None:
            send({"jsonrpc": "2.0", "id": rid, "result": {"outcome": "promptRequired", "reason": "noRunningTurn"}})
        else:
            text = " ".join(b.get("text", "") for b in params.get("prompt", []) if isinstance(b, dict))
            turn[1].put(text)
            send({"jsonrpc": "2.0", "id": rid, "result": {"outcome": "injected"}})
    elif method == "session/cancel":
        STATE["cancel"].set()
    elif method in ("session/set_model", "session/set_config_option"):
        model = params.get("modelId") or (params.get("value") if params.get("configId") == "model" else None)
        if model:
            STATE["model"] = model
        send({"jsonrpc": "2.0", "id": rid, "result": {}})
        update("config_option_update", configOptions=[{"id": "model", "name": "Model", "category": "model",
                                                        "type": "select", "currentValue": STATE["model"], "options": MODELS}])
    elif method == "session/close":
        send({"jsonrpc": "2.0", "id": rid, "result": {}})
    elif rid is not None:
        send({"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": f"Method not found: {method}"}})


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        handle(msg)


if __name__ == "__main__":
    main()
