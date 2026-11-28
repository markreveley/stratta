#!/usr/bin/env python3
"""Write the diagrams in assets/diagrams/ as SVG.

    python3 scripts/make_diagrams.py

Each diagram is drawn from the primitives in scripts/svg.py and inlined into a page by
scripts/build.py. The long title of each one is its text alternative.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from svg import Svg  # noqa: E402


def system():
    d = Svg("system", 720, 396,
            "Stratta today. In the middle, the core: one BEAM node holding a ThreadServer process per thread, the Timeline "
            "it folds events into, the Harness session that speaks ACP to an agent program outside the node, and beside "
            "them PubSub, the API, the Socket and the Store. On the left, a browser reaches a LiveView that runs in the "
            "same node and calls the core's functions directly. On the right, the stratta terminal commands reach the "
            "core through the Unix socket.")
    d.box(170, 60, 380, 262, kind="panel")
    d.text(186, 82, "core/  the daemon: one BEAM node", size=12.5, weight=600)
    d.box(190, 96, 170, 52, "ThreadServer", "one process per thread", kind="accent")
    d.box(190, 162, 170, 46, "Timeline", "events folded into items")
    d.box(190, 222, 170, 52, "Harness session", "speaks ACP")
    d.box(380, 96, 150, 46, "PubSub", "topics")
    d.box(380, 152, 150, 46, "Stratta.API", "named operations", kind="accent")
    d.box(380, 208, 150, 46, "Socket", "frames on a Unix socket")
    d.box(380, 264, 150, 46, "Store", "files in ~/.stratta")
    d.arrow(275, 148, 275, 162)
    d.arrow(275, 222, 275, 208)

    d.box(20, 96, 110, 40, "browser")
    d.box(20, 176, 110, 52, "LiveView", "gui/, same node", kind="warm")
    d.arrow(75, 136, 75, 176, both=True)
    d.arrow(130, 202, 168, 202, both=True)
    d.text(149, 194, "calls", size=10.5, anchor="middle", fill="var(--ink-2)")

    d.box(590, 96, 116, 118)
    d.text(648, 116, "tui/", size=12.5, weight=600, anchor="middle")
    for k, line in enumerate(("stratta watch", "stratta attach", "stratta approve 2a", "stratta ship")):
        d.text(648, 138 + 20 * k, line, size=10.5, anchor="middle", mono=True)
    d.arrow(590, 214, 532, 231, both=True)
    d.text(568, 248, "Unix socket", size=10.5, anchor="middle", fill="var(--ink-2)")

    d.box(190, 340, 170, 46, "agent program", "any agent CLI, or the demo", kind="warm")
    d.arrow(275, 274, 275, 340, both=True)
    d.text(285, 334, "stdin and stdout", size=10.5, fill="var(--ink-2)")
    d.save()


def request():
    lanes = [("agent", 62), ("Harness session", 190), ("ThreadServer", 330), ("PubSub", 458),
             ("a front end", 584), ("operator", 700)]
    d = Svg("request", 760, 392,
            "The life of one permission request, as nine messages between six parties. 1: the agent sends "
            "session/request_permission to the Harness session. 2: the session emits an approval_requested event, which "
            "reaches the ThreadServer. 3: the ThreadServer folds it into the timeline, where it becomes request a. 4: the "
            "ThreadServer broadcasts a snapshot on PubSub. 5: PubSub delivers it to every front end watching. 6: the "
            "operator types approve 2a. 7: the front end sends the operation thread.approve. 8: the ThreadServer calls "
            "respond_approval on the session. 9: the session returns the outcome to the agent, whose turn continues.")
    for name, x in lanes:
        kind = "warm" if name == "agent" else ("accent" if name == "ThreadServer" else "plain")
        d.box(x - 56, 14, 112, 34, name, kind=kind, size=12)
        d.line(x, 48, x, 380, stroke="var(--rule)", dashed=True)
    x = dict(lanes)
    steps = [
        ("agent", "Harness session", "1  session/request_permission", "warm"),
        ("Harness session", "ThreadServer", "2  event: approval_requested", "ink"),
        ("ThreadServer", "ThreadServer", "3  timeline: it becomes request a", "accent"),
        ("ThreadServer", "PubSub", "4  broadcast snapshot", "ink"),
        ("PubSub", "a front end", "5  push", "ink"),
        ("operator", "a front end", "6  approve 2a", "ink"),
        ("a front end", "ThreadServer", "7  operation thread.approve", "accent"),
        ("ThreadServer", "Harness session", "8  respond_approval", "ink"),
        ("Harness session", "agent", "9  outcome: allowed", "warm"),
    ]
    y = 84
    for a, b, label, color in steps:
        if a == b:
            d.circle(x[a], y, 5, kind="accent")
            d.text(x[a] + 12, y + 4, label, size=11.5, fill="var(--ink-2)")
        else:
            d.arrow(x[a], y, x[b], y, color=color)
            left = min(x[a], x[b])
            d.text(left + 8, y - 7, label, size=11.5, fill="var(--ink-2)")
        y += 35
    d.save()


def tree():
    d = Svg("tree", 760, 300,
            "The supervision tree of the core. At the top Stratta.Supervisor, strategy one for one. Under it six "
            "children: Phoenix.PubSub, Stratta.Store, the Registry named ThreadRegistry, the DynamicSupervisor named "
            "ThreadSupervisor, a Task.Supervisor, and Stratta.Socket. ThreadSupervisor has one ThreadServer child per "
            "open thread, each restarted only after a crash. The Task.Supervisor holds one short-lived task per socket "
            "connection and per API call. The Socket process has a linked acceptor. The registry maps thread ids to "
            "ThreadServer processes.")
    d.box(280, 12, 200, 44, "Stratta.Supervisor", "strategy :one_for_one", kind="accent")
    kids = [("PubSub", "Phoenix.PubSub"), ("Store", "GenServer"), ("ThreadRegistry", "Registry"),
            ("ThreadSupervisor", "DynamicSupervisor"), ("TaskSupervisor", "Task.Supervisor"), ("Socket", "GenServer")]
    for i, (name, sub) in enumerate(kids):
        bx = 12 + i * 124
        d.line(380, 56, bx + 57, 108, stroke="var(--ink-3)")
        d.box(bx, 108, 114, 46, name, sub, size=10.5)
    for bx, sub in ((300, "thread 1"), (404, "thread 2")):
        d.line(441, 154, bx + 48, 214, stroke="var(--ink-3)")
        d.box(bx, 214, 96, 46, "ThreadServer", sub, kind="accent", size=11)
    d.text(400, 280, "restart: :transient", size=11, anchor="middle", fill="var(--ink-2)", mono=True)
    d.line(565, 154, 565, 214, stroke="var(--ink-3)")
    d.box(510, 214, 110, 46, "tasks", "one per connection", size=11.5)
    d.line(691, 154, 691, 214, stroke="var(--ink-3)")
    d.box(636, 214, 110, 46, "acceptor", "linked to Socket", size=11.5)
    d.arrow(310, 154, 334, 212, dashed=True, color="accent")
    d.text(222, 196, "finds by thread id", size=11, fill="var(--accent)")
    d.save()


def turn():
    d = Svg("turn", 760, 214,
            "One Jido turn on a live agent, left to right. A Signal arrives; a route picks an Action; the Action does its "
            "work; the result is a candidate, the next agent value plus a list of Directives. A dashed vertical line marks "
            "the commit. Before it, any failure discards the candidate and the agent is unchanged. After it, the caller is "
            "answered and then the Directives run as effects, and nothing can undo the commit.")
    d.box(12, 74, 92, 52, "Signal", "typed message", kind="accent")
    d.box(128, 74, 96, 52, "route", "picks an Action")
    d.box(248, 74, 96, 52, "Action", "does the work")
    d.box(368, 74, 130, 52, "candidate", "next agent + directives", kind="warm")
    d.box(542, 74, 96, 52, "caller", "is answered")
    d.box(662, 74, 86, 52, "effects", "directives run", kind="good")
    for x1, x2 in ((104, 128), (224, 248), (344, 368), (498, 542), (638, 662)):
        d.arrow(x1, 100, x2, 100)
    d.line(520, 24, 520, 196, stroke="var(--accent)", dashed=True)
    d.text(520, 18, "commit", size=12, weight=600, anchor="middle", fill="var(--accent)")
    d.text(255, 160, "before: a failure discards the candidate,", size=11.5, anchor="middle", fill="var(--ink-2)")
    d.text(255, 176, "and the agent is unchanged", size=11.5, anchor="middle", fill="var(--ink-2)")
    d.text(645, 160, "after: nothing can", size=11.5, anchor="middle", fill="var(--ink-2)")
    d.text(645, 176, "undo the commit", size=11.5, anchor="middle", fill="var(--ink-2)")
    d.save()


def routes():
    d = Svg("routes", 760, 236,
            "Two ways to bring Jido into Stratta, which differ in who owns the Harness session. Route A, policy only: "
            "ThreadServer still owns the session, and a Jido agent beside it holds the rules; ThreadServer hands it a "
            "request and gets an answer back. Route B, the plugin owns the thread: a Jido AgentServer with the Harness "
            "plugin owns the session, and ThreadServer becomes a client that sends it signals.")
    d.box(12, 12, 358, 212, kind="panel")
    d.text(28, 36, "Route A: policy only", size=13, weight=600)
    d.box(28, 56, 150, 52, "ThreadServer", "owns the session", kind="accent")
    d.box(28, 160, 150, 46, "Harness session")
    d.arrow(103, 108, 103, 160)
    d.box(214, 56, 140, 52, "Jido agent", "rules as actions")
    d.arrow(178, 72, 214, 72)
    d.arrow(214, 94, 178, 94)
    d.text(196, 132, "a request goes over,", size=11, anchor="middle", fill="var(--ink-2)")
    d.text(196, 147, "an answer comes back", size=11, anchor="middle", fill="var(--ink-2)")

    d.box(390, 12, 358, 212, kind="panel")
    d.text(406, 36, "Route B: the plugin owns the thread", size=13, weight=600)
    d.box(406, 56, 140, 52, "ThreadServer", "a client of the agent")
    d.box(582, 56, 150, 52, "Jido AgentServer", "with the Harness plugin", kind="accent")
    d.box(582, 160, 150, 46, "Harness session")
    d.arrow(657, 108, 657, 160)
    d.arrow(546, 82, 582, 82)
    d.text(476, 132, "ThreadServer sends signals", size=11, anchor="middle", fill="var(--ink-2)")
    d.text(476, 147, "and holds no session", size=11, anchor="middle", fill="var(--ink-2)")
    d.save()


def authority():
    d = Svg("authority", 760, 250,
            "Two models of who may answer a permission request. Today: anything that can open the control socket may "
            "answer, and that includes a shell command run by an agent, so agent 3 can approve agent 2's request. "
            "Planned: an answer must present a grant. The operator's front end holds one; the agent's shell command has "
            "none and is refused; a reviewer thread may hold a narrowed grant that covers only what was delegated.")
    d.box(12, 12, 358, 226, kind="panel")
    d.text(28, 36, "Today: being able to open the socket", size=13, weight=600)
    d.box(28, 56, 150, 40, "operator's client")
    d.box(28, 132, 150, 52, "agent 3's shell", "runs stratta approve 2a", kind="bad")
    d.box(244, 92, 110, 52, "daemon", "answers 2a", kind="accent")
    d.arrow(178, 76, 244, 108, color="good")
    d.arrow(178, 158, 244, 130, color="bad")
    d.text(28, 212, "both callers are the same user, so both get in", size=11.5, fill="var(--ink-2)")

    d.box(390, 12, 358, 226, kind="panel")
    d.text(406, 36, "Planned: a grant, held and presented", size=13, weight=600)
    d.box(406, 56, 150, 40, "operator + grant", kind="good")
    d.box(406, 108, 150, 40, "agent 3's shell", kind="bad")
    d.box(406, 160, 150, 52, "reviewer thread", "narrowed grant: reads", kind="warm")
    d.box(622, 92, 110, 66, "daemon", "checks the grant", kind="accent")
    d.arrow(556, 76, 622, 104, color="good")
    d.arrow(556, 128, 622, 128, color="bad", dashed=True)
    d.text(589, 122, "refused", size=10.5, anchor="middle", fill="var(--bad)")
    d.arrow(556, 186, 622, 150, color="warm")
    d.save()


def lanes():
    d = Svg("lanes", 760, 388,
            "The nineteen steps of next.md that build something, arranged in four lanes, with an arrow wherever one step needs another. Record: "
            "step 9, decision records, leads to step 10, traces, and to step 20, claims, which leads to step 21, context "
            "seeds. Authority: step 12, the hole reproduced by two routes, leads to step 16, the local grant; step 11, "
            "policy rules, needs step 9; step 23, narrowing for views, needs steps 14 and 16. Surfaces: step 13, "
            "operation specs and the socket protocol, leads to step 14, views cut out of the app, which leads to step 22, "
            "the timing view; step 18, choices, also leads to step 22; steps 17, the terminal client, and 13, the thread "
            "tree, need nothing. Places: step 8, the hook spike, leads to step 15, pane requests; steps 24, 1 and 25 "
            "stand alone.")
    bands = [("Record", 12, 86), ("Authority", 104, 86), ("Surfaces", 196, 90), ("Places", 292, 84)]
    for name, y, h in bands:
        d.box(12, y, 736, h, kind="panel")
        d.text(26, y + 20, name, size=12.5, weight=600)

    def step(x, y, w, n, label, kind="plain"):
        d.box(x, y, w, 30, "%s  %s" % (n, label), kind=kind, size=11.5)

    # Record
    step(120, 24, 150, 9, "decision records", "accent")
    step(320, 24, 100, 10, "traces")
    step(320, 60, 100, 20, "claims")
    step(470, 60, 130, 21, "context seeds")
    d.arrow(270, 39, 320, 39)
    d.arrow(270, 48, 320, 71)
    d.arrow(420, 75, 470, 75)
    # Authority
    step(120, 112, 130, 12, "the hole, tested")
    step(320, 112, 110, 16, "local grant", "accent")
    step(320, 150, 110, 11, "policy rules")
    step(584, 150, 158, 23, "narrowing for views")
    d.arrow(250, 127, 320, 127)
    d.arrow(430, 135, 584, 158)
    d.arrow(200, 54, 330, 112, color="accent")
    d.arrow(170, 54, 320, 160, color="accent")
    # Surfaces
    step(120, 206, 150, 13, "specs, protocol")
    step(320, 206, 150, 14, "views from the app", "accent")
    step(520, 206, 120, 22, "timing view")
    step(120, 246, 150, 17, "terminal client")
    step(320, 246, 110, 18, "choices")
    step(520, 246, 120, 19, "thread tree")
    d.arrow(270, 221, 320, 221)
    d.arrow(470, 221, 520, 221)
    d.arrow(430, 254, 520, 232)
    d.arrow(470, 210, 600, 180, color="accent")
    # Places
    step(120, 320, 120, 8, "hook spike")
    step(300, 320, 130, 15, "pane requests")
    step(450, 320, 104, 24, "remote")
    step(566, 320, 84, 1, "report")
    step(660, 320, 82, 25, "exit test")
    d.arrow(240, 335, 300, 335)
    d.save()


if __name__ == "__main__":
    for fn in (system, request, tree, turn, routes, authority, lanes):
        fn()
    print("make_diagrams.py: wrote 7 diagrams")
