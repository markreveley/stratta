<p class="kicker">Stratta architecture tutorial, web edition</p>

# Tutorial: Stratta's architecture, from the process up

## About this tutorial

Stratta is a control plane for coding agents, written in Elixir. Its repository holds a working system, a list of twenty-seven next steps (`next.md`), and twenty-three plans that say what those steps build. The plans were in `plans/` when this was written and are now under `md/plans/`, each in a dated folder: `plans/event-log.md` is `md/plans/2026-11-26-event-log/event-log.md`. This tutorial is kept in the same repository, in `md/docs/tutorial/`. This tutorial describes nineteen of the steps and twenty-one of the plans; the eight newer steps and the two newer plans are named in [[s36]]. This tutorial explains the concepts a reader needs in order to read that list and those plans and know, at each sentence, what is being proposed and why it has the shape it has.

It is written for one reader: someone who has worked through an introductory Elixir course, as far as a first GenServer, and knows how the BEAM holds data in memory, who has run Stratta, and who did not write most of its code. It assumes pattern matching, immutable data, folds, `with`, and the idea of a process with a mailbox. It assumes nothing about OTP beyond one small counter server, and nothing about Jido, agent protocols, or capability security. Each term is explained the first time it appears, in **bold**, and the Glossary at the end lists every term with the section that introduced it.

There are seven parts:

[[p1]] describes the system as it runs today, and follows one permission request from an agent to the operator and back. Every later part explains one stretch of that journey.

[[p2]] covers the runtime underneath: processes, GenServer, supervisors, registries and tasks, each shown where Stratta uses it.

[[p3]] covers how a thread's state is computed and how everyone watching hears about it: a pure fold over events, and publish and subscribe.

[[p4]] covers the edges of the node: the control socket, the API behind it, the agent programs outside it, the two protocols an agent can report through, and the terminal.

[[p5]] covers behaviours and Jido, the framework the first planned integration is built on, the one decision that integration turns on, and the parts of Jido the plans have only begun to draw on.

[[p6]] covers the ideas in the plans that are not about Elixir at all: a decision as a record, traces, policy, authority, one registry of operations, code written by a model, claims, two kinds of graph, and where a thread's files and processes live.

[[p7]] goes back to `next.md` with all of that in hand: the dependency graph behind the list, and what each step asks the reader to know.

The tutorial describes Stratta at commit `a7c451f` (25 November 2026), with two exceptions: the list of plans in [[s4]] and all of [[p7]] follow `next.md` and `plans/` as reordered on 26 November 2026, when the operator chose to build Stratta first as a guest in a host terminal; and [[s25]], [[s34]] and the end of [[s12]] follow two plans added later that day. Both are as of commit `2846650`. That commit also holds the one change to Stratta's code since `a7c451f`, the repair that [[s12]] describes. Every excerpt of Stratta's code shown here was compared with that commit by a script. Every excerpt of lab code is cut by the build from a file that was run, and the transcripts are kept with the tutorial. Stratta itself was not run while writing: the authoring environment had an older Elixir than Stratta requires. One of its modules was run by itself, for [[s12]]. The Sources section says exactly what was checked and how.

## Contents and how to read this

[[p1]] is short and should be read first by everyone. [[p2]] to [[p4]] are the Elixir and OTP half; a reader who already writes OTP applications can skim them for the sentences that name Stratta's modules. [[p5]] and [[p6]] are the half that the plans lean on most, and [[p6]] can be read without [[p5]] except for sections 28, 31 and 34. [[p7]] is a reference: return to it when starting a step.

Seven labs go with the text. Each is one Elixir script with its tests, a miniature of one piece of Stratta, with the parts to write left as stubs. They need Elixir and nothing else; [[s39]] lists them. Do a lab when its section sends you there, before reading on.

Two conventions. **Today** means the code at the commit above. **Planned** means written in a plan and not built; nothing planned is described as if it existed. Where the plans and the reference material disagree, the text says so, and [[s40]] collects those places.

@@contents
@@part 1 | The system today | what runs now, and one request followed end to end

### 1. What Stratta is for

A **coding agent** is a program that takes a request in words, such as "add a greeting file", and carries it out in a folder of source code by running a language model in a loop: the model proposes an action, the program performs it, the result goes back to the model, and so on until the model says it is done. Claude Code, Codex and Gemini CLI are coding agents. Each is a command-line program with its own login, and Stratta calls the installed program an **agent** and the configuration that knows how to start one a **provider**.

One such loop, from a request to the point where the agent stops and waits for the next one, is a **turn**. During a turn the agent uses **tools**: reading a file, editing a file, running a shell command. Some tool uses are safe to perform without asking and some are not, so an agent can be configured to stop before an action and ask. That question is a **permission request**. It carries what the agent intends to do (the tool, its arguments, and for an edit the proposed change), and the agent's turn does not continue until somebody answers allow or deny.

Running one agent in one terminal needs nothing more. Running five, on different branches of several repositories, raises questions no single agent can answer: which of them is waiting on me, what did each one change, which change is ready to ship. A **control plane** is the part of a system that answers such questions and carries the decisions back; the agents doing the work are the other part. Stratta is a control plane for coding agents. The person using it is the **operator**.

Stratta's unit is the **thread**: one conversation with one agent in one working folder, with everything that happened in it. A thread can be given its own git branch and **worktree**, a second checkout of the same repository in another folder, so that parallel threads never edit each other's files. The operator can watch a thread, send it messages, **steer** it (add a message to a turn that is still running), interrupt it, answer its permission requests, read its diff, and ship it: commit, push and open a pull request.

Stratta stores no credentials. It starts each agent program as the operator, and the program uses its own existing login.

### 2. One daemon, two front ends

Stratta is three Mix projects in one repository.

`core/` is the **daemon**: a long-running program with no user interface that owns the agents, the threads and their history. `gui/` is a web application the operator opens in a browser. `tui/` builds `stratta`, a command for the terminal with a dashboard, a live viewer for one thread, a diff view, and one-shot commands such as `stratta approve 2a`. The two user interfaces are **front ends**: they show what the daemon holds and send it commands, and neither owns anything. Several can watch the same thread at once.

::: diagram id=fig-system file=system.svg
Stratta today. The core is one node. The app runs inside that node and calls the core's functions; the terminal client is a separate program that reaches the core through a socket. The agent is a third program, outside both.
:::

The two front ends reach the daemon differently, and the difference matters to several plans.

A running instance of the Erlang virtual machine is a **node**. Every Elixir process lives in some node, and processes in one node can call each other's functions and send each other messages directly. The app is built so that starting it also starts the core *in the same node*: `gui/mix.exs` lists the core as a dependency, and an application's dependencies are started before it. A running app is therefore also the daemon, and its pages call modules such as `Stratta.ThreadServer` as ordinary functions.

The terminal client is a separate operating-system program that starts, does one thing and often exits. It cannot call the daemon's functions. It connects to a **socket**, a file-like endpoint that two programs on one machine can exchange bytes through, at `~/.stratta/stratta.sock`, and sends named operations as JSON. [[s15]] and [[s16]] cover the socket and the operations.

So today there are two paths into the core: direct function calls from the app, and operations over the socket from the terminal. The plan called "the app first" removes the first path, so that everything goes through the operations and it stops mattering where the daemon runs ([[s35]]).

### 3. The life of one permission request

Almost every plan changes what happens to a permission request, so it is worth following one all the way through before looking at any part closely. The operator has typed `stratta new "add a greeting file"` and the agent has decided to create `hello.txt`.

::: diagram id=fig-request file=request.svg
One permission request, today. Messages 1 and 9 cross between programs. Messages 2 to 5, 7 and 8 are between processes inside the daemon or between the daemon and a front end. Message 6 is a person typing.
:::

1. The agent program writes a message on its standard output saying it wants permission to write a file. The message follows a protocol, ACP, covered in [[s18]].
2. The daemon's library for running agents, Jido.Harness, reads the message and turns it into an **event**: a small record saying that something happened, with a type (`:approval_requested`), a sequence number and a payload. The event reaches the process that owns this thread, a `Stratta.ThreadServer`.
3. The ThreadServer folds the event into the thread's **timeline**, the ordered list of things to show for this thread. There the request gets a letter. A thread sits in a numbered **slot** so that people can say `2` instead of an id, and the first request of the thread in slot 2 is named `2a`. That **request name** never refers to anything else afterwards.
4. The ThreadServer announces the thread's new state to anyone listening, by broadcasting a **snapshot**: the whole current state of the thread as one value.
5. Every front end watching the thread receives the snapshot and redraws. The dashboard marks thread 2 as waiting; the app shows a card with the proposed file.
6. The operator reads it and types `stratta approve 2a`, or presses a key in the viewer, or clicks in the app.
7. The front end sends the operation `thread.approve` to the daemon, which finds the thread and the request the name refers to.
8. The ThreadServer tells the Harness session the answer.
9. Harness writes the answer on the agent's standard input. The agent creates the file and its turn continues.

Three things about this journey are worth noticing now, because the plans are about them.

Nothing is written down about the *decision*. The timeline has an item for the request and marks it approved, and that is all: who answered, when, what they were looking at, and how long the agent waited are not recorded anywhere ([[s26]]).

Nothing checks who is answering. Step 7 is accepted from any program that can open the socket, which includes a shell command run by another agent ([[s29]]).

And a person answers every request, including the hundredth request to read a file ([[s28]]).

### 4. What the plans change

The twenty-one plans described here fall into four groups. The names of the groups are this tutorial's; the plans do not use them.

**The record.** Seven plans make what happened in a thread into data that can be queried later. *Decisions as records* writes a record whenever a request is answered. *Traces and decision measures* exports a thread as a trace and derives a few numbers, the first being how long requests wait. *Claims recorded as the work happens* turns each answered request into a claim with its grounds. *Context as a recorded query* builds the material a continued thread starts with out of those claims, and measures whether that beats a transcript. *Context assembled for each request* is an experiment beside it: a fresh run of the agent for every request, started from text Stratta assembles, to find out whether Stratta should ever own an agent's loop. *Ids that survive a restart, and a log of events* repaired how a timeline's items are named and proposes keeping the events a timeline is folded from. *Graphs* gives these plans one name, the record graph, and sets beside it a graph of work across threads.

**Authority.** Three plans are about who or what may answer a request. *Policy as actions* lets rules answer the requests a rule can settle, and is where Jido comes in. *Authority for an answer* replaces "can open the socket" with a grant that must be presented. *An agent as an approver* lets a second thread answer requests that need the proposal read, under a narrowed grant.

**Surfaces.** Eight plans are about the operator's interfaces. *Views as separate programs* makes the operator's own terminal the environment: Stratta supplies views, each started by a command and placed in a pane, and the app is taken apart into pages that each draw one thing. *Pointing and choosing* lets a request carry a list of options and lets a view send a reference to a thing without describing it. *The app first* gives the app a command bar, files, an editor and a shell; since 26 November 2026 it waits as a follow-up. *Code mode* describes every operation precisely enough to generate things from, and later lets a model drive Stratta by writing scripts. *Surfaces drawn from behaviour* generates a command palette from those descriptions. *Slash commands* keeps the list of commands an agent advertises. *A composer you can edit* and *Hyperlinks in the terminal client* improve the terminal viewer.

**Places.** Three plans are about where things run. *Pane threads* lets an agent run in its own terminal interface and still report its requests to Stratta. *Remote access* reaches a daemon from another machine. *Where a thread's files and processes live* names the present arrangement as one implementation of several.

`next.md` puts phases of these plans into one order. [[p7]] returns to it.
@@part 2 | Processes and supervision | the runtime underneath, shown where Stratta uses it

### 5. A process is the unit of everything

Lesson 10 of the Elixir course defined a **process**: a unit of execution scheduled by the virtual machine, with its own memory and a **mailbox**, a queue of messages other processes have sent it. A process's memory is private. The only way to affect another process is to send it a message, which copies the message into the receiver's mailbox; page 9 of the memory-model wiki shows the copy.

The BEAM Book's chapter on processes puts it in four words: a process is "just memory", meaning a stack, a heap, a mailbox and a small control block. That is why processes are cheap, and why an Elixir program uses them where another language would use an object, a thread or a callback. Stratta has one process per open thread, one per socket connection, one per browser page, one per operation in flight, and one reading each agent's event stream.

Two properties of processes carry most of Stratta's design.

**Isolation.** A process that crashes takes nothing with it but its own memory. A thread whose agent sends something the code did not expect cannot corrupt another thread, because there is no memory they share.

**Fair scheduling.** The virtual machine runs many processes on a few operating-system threads by giving each one a budget and switching when it is spent. The BEAM Book's scheduling chapter describes the budget as a count of **reductions**, roughly function calls, with a few thousand per turn at the processor. A process cannot hold the processor by looping, because looping in Elixir is calling a function. So a ThreadServer busy folding a burst of events does not make the dashboard freeze.

The consequence to carry forward: in Stratta, "who owns this state" always has an answer, the answer is a process, and everything else talks to that process by message.

### 6. GenServer: a process with a contract

A **GenServer** is a process that follows a standard pattern: it keeps a state, waits for a message, handles it with a function you write, and loops with the new state. OTP, the set of libraries that ships with Erlang, provides the loop. You provide the functions. Lesson 10 showed the split that makes one readable: the *client* functions run in whichever process calls them and only send a message, and the *callbacks* run in the server process, one message at a time.

There are three ways a message reaches a GenServer, and Stratta's `ThreadServer` uses all three.

A **call** is a request that waits for a reply: `GenServer.call(server, message)` blocks the caller until the server's `handle_call/3` returns `{:reply, value, new_state}`, or until a timeout, five seconds unless stated. Answering a permission request is a call, because the front end needs to know whether it worked.

A **cast** is a message with no reply. ThreadServer has none.

Anything else that arrives, a message sent with plain `send/2` or a timer firing, goes to `handle_info/2`. This is how a thread's events arrive. A helper process reads the agent's event stream and sends each event to the ThreadServer as an ordinary message:

::: example id=fig-handle-info
title: Stratta: core/lib/stratta/thread_server.ex
```elixir
  def handle_info({:harness_events, session_id, events}, %{session_id: session_id} = state) do
    state =
      Enum.reduce(events, state, fn event, acc ->
        acc
        |> update_timeline(&Timeline.apply_event(&1, event), false)
        |> track_session(event)
      end)

    {:noreply, state |> schedule_save() |> broadcast()}
  end
```
caption: Events arrive as messages. The pattern `%{session_id: session_id}` uses the same variable twice, so the clause matches only events from the session this server currently holds; events from an earlier session fall through to a clause that ignores them.
:::

Because a GenServer handles one message at a time, its state needs no lock. Two front ends that approve the same request at the same instant become two messages in one mailbox; the first is handled completely before the second is looked at, and the second finds the request already answered. This is **serialisation**: turning concurrent requests into a sequence by sending them all through one process. `Stratta.Store` exists for exactly this reason. It is a GenServer that holds the list of projects and threads, and every change to that list is a call to it, so two writers can never interleave. It also writes its file the safe way, to a temporary name and then a rename, so that a crash mid-write leaves the old file and never half of a new one.

A timer is a message to yourself, later. `Process.send_after(self(), :save, 400)` puts `:save` in the server's own mailbox after 400 milliseconds, and `handle_info(:save, state)` does the write. ThreadServer sets that timer only if none is already running, so a burst of a hundred events causes one write. Waiting for a quiet moment before doing expensive work is **debouncing**.

::: note
Lab 1 (`exercises/01_thread_server.exs`) builds a small ThreadServer: requests with letters, answers that apply once, and a debounced save. Do it now.
:::

::: example id=fig-lab1
title: The debounce, from the lab's solution
@file elixir solutions/01_thread_server.exs | # One timer at a time | defp schedule_save(state), do: state
caption: Two function clauses. The first matches only when no timer is set. The second matches otherwise and does nothing.
:::

### 7. Links, monitors and letting it crash

Processes fail. Elixir's answer is to keep the failure small and make sure someone finds out.

A **link** joins two processes so that if either exits abnormally the other receives an exit signal and exits too. Links are for processes that make no sense without each other. A **monitor** is one-directional: the watcher receives a `{:DOWN, ...}` message when the watched process exits, and carries on. Lesson 10 introduced both.

A process can choose to receive exit signals as messages by **trapping exits** (`Process.flag(:trap_exit, true)`). `Stratta.Socket` does this. It starts a helper that waits for connections and links to it; if the helper dies, the Socket process receives `{:EXIT, pid, reason}` as a message and stops itself deliberately, so that whatever supervises it can start a fresh pair. Trapping exits has a second effect. A GenServer's `terminate/2` callback runs when its supervisor shuts it down only if the process traps exits; a process that does not is simply killed. Socket relies on this to remove its socket file on the way out. ThreadServer also defines a `terminate/2`, to save the timeline and close the agent's session, and does not trap exits; [[s40]] comes back to that.

**Let it crash** is the habit these mechanisms allow. Code handles the failures it can do something useful about and does not try to anticipate the rest. An unexpected message, a malformed payload or a bug raises, the process dies with its private state, and a supervisor ([[s8]]) starts a clean one. The alternative, defensive code on every line, tends to keep a process alive in a state nobody designed.

Stratta draws the line between the two kinds of failure in one visible place. `Stratta.API`, the module every operation goes through, never raises ([[s16]]): a bad thread name or a failed push is an expected failure and comes back as `{:error, message}` for the operator to read. A ThreadServer receiving an event it cannot fold is not expected, and nothing catches it.

### 8. Supervisors and the application

A **supervisor** is a process whose only job is to start other processes, its **children**, and to restart them when they exit. A supervisor's children can be supervisors, so a running system is a **supervision tree**.

Two settings decide what restarting means. The supervisor's **strategy** says which children to restart when one dies: `:one_for_one` restarts only the one that died, and `:one_for_all` restarts every child, for children that depend on each other. Each child's **restart value** says when it is restarted at all: `:permanent` always, `:transient` only after an abnormal exit, `:temporary` never. A supervisor also counts restarts, and if a child dies more than a few times in a few seconds (three in five, unless stated) the supervisor gives up and exits itself, passing the problem to its own supervisor.

An OTP **application** is a unit that can be started and stopped as a whole: a set of modules, and usually a function that starts its supervision tree. Here is all of Stratta's core:

::: example id=fig-children
title: Stratta: core/lib/stratta/application.ex
```elixir
    children =
      [
        {Phoenix.PubSub, name: Stratta.PubSub},
        Stratta.Store,
        {Registry, keys: :unique, name: Stratta.ThreadRegistry},
        {DynamicSupervisor, name: Stratta.ThreadSupervisor, strategy: :one_for_one},
        {Task.Supervisor, name: Stratta.TaskSupervisor}
      ] ++ if(Application.get_env(:stratta, :socket, true), do: [Stratta.Socket], else: [])
```
caption: The daemon's children, started in this order under a `:one_for_one` supervisor. Each entry is a **child specification**: a module, or a module with its options.
:::

::: diagram id=fig-tree file=tree.svg
The same list as a tree, with what each child goes on to start. The dashed arrow is a lookup, not supervision.
:::

The module's own comment states the consequence that [[s2]] relied on: any node that starts this application is a Stratta daemon. The app does not contain a copy of the daemon. It depends on this application, so starting the app starts this tree first, in the same node. The web application's own tree has a single child, the web endpoint.

The order of the list is the order of starting, and it encodes dependencies: the Store must exist before any thread can load, the registry before any thread can be named, and the socket last, so that no client can connect to a daemon that is still starting.

### 9. One process per thread, found by name

The number of threads is not known when the daemon starts, so ThreadServers cannot be in the list above. Two of the children exist to solve that.

A **DynamicSupervisor** is a supervisor that starts with no children and is given them one at a time while running. `Stratta.ThreadSupervisor` is one. Asking it to start a child for thread `tAb3` starts a ThreadServer process for that thread and supervises it.

A **Registry** is a table from keys to processes, kept by the runtime, that cleans up after itself: when a registered process exits, its entry disappears. `Stratta.ThreadRegistry` maps thread ids to ThreadServers. A process identifier, a **pid**, is useless to remember, because a restarted process has a new one. So nothing in Stratta holds a ThreadServer's pid. Callers use a **via tuple**, a name of the form `{:via, Registry, {registry, key}}` that GenServer resolves through the registry at the moment of each call.

::: example id=fig-ensure
title: Stratta: core/lib/stratta/thread_server.ex
```elixir
  def start_link(thread_id), do: GenServer.start_link(__MODULE__, thread_id, name: via(thread_id))

  def via(thread_id), do: {:via, Registry, {Stratta.ThreadRegistry, thread_id}}

  def ensure_started(thread_id) do
    case DynamicSupervisor.start_child(Stratta.ThreadSupervisor, {__MODULE__, thread_id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end
```
caption: Starting a thread's process on demand. The registry's keys are unique, so a second start for the same thread fails with `:already_started`, and `ensure_started/1` treats that as success. The function can be called any number of times, by any number of callers, with the same result: it is **idempotent**.
:::

Each client function that needs the thread's process calls `ensure_started/1` first, so the process exists from the first time anything asks it something. Two details complete the design.

ThreadServer is declared `use GenServer, restart: :transient`. A ThreadServer that crashes is restarted; one that stops normally stays stopped.

And a restarted ThreadServer comes back with *empty memory*. Its `init/1` therefore rebuilds the state from disk: the thread's record from the Store and its timeline from the thread's file. Supervision restores the process; persistence restores what it knew. What cannot be restored is the conversation with the agent program, which died with the old process's session, so `init/1` marks any request that was waiting as expired and adds a notice to the timeline.

Some questions must not start a process at all. Listing fifty threads should not create fifty ThreadServers. `ThreadServer.summary/1` looks the thread up in the registry and, if it is not running, answers `:detached` without starting anything.

::: note
Lab 2 (`exercises/02_supervision.exs`) builds this arrangement and tests the three behaviours above: idempotent start, restart with empty state after a kill, and no restart after a normal stop.
:::

### 10. Tasks: work that must not block the owner

A GenServer handles one message at a time, so while it is doing something slow it answers nobody. The rule that follows is that a process that owns state should decide quickly and hand slow work to another process. A **Task** is the standard short-lived process for that: it runs one function and exits. A **Task.Supervisor** is a supervisor for tasks, so that they belong to the tree and are cleaned up with it.

Stratta uses tasks in four places.

*Following an agent.* Harness offers a session's events as a stream that blocks until the next event. ThreadServer cannot sit in that stream, so it starts a task that does, and that sends each event home as a message. This is the helper process of [[s6]]. If a session is replaced, the old follower's messages carry the old session id and are ignored.

*Serving a connection.* Each client connected to the socket is a task under `Stratta.TaskSupervisor`, so one slow terminal cannot delay another ([[s15]]).

*Running an operation.* Inside a connection, each request is run in a further task, and the reply is sent back to the connection as a message. A connection can therefore have several requests in flight, and a push to the client is never stuck behind a slow `thread.ship`.

*Asking many things at once.* Checking which agents are installed means running a dozen programs with `--version`. `Stratta.Providers` does it with `Task.async_stream/3`, six at a time, and keeps the answers for a minute.

The same rule appears in Jido, stated outright: its guide to OTP says the agent's server process "only decides what happens next" and hands slow work to other processes ([[s22]]). It is one of the reasons the two fit together.
@@part 3 | State as a fold, and telling everyone | how a thread's state is computed, kept and announced

### 11. A pure core inside a process shell

A ThreadServer owns a thread's state, but it does not compute it. The computing is done by `Stratta.Timeline`, a module with no process, no disk and no network in it.

A **pure function** is one whose result depends only on its arguments and which changes nothing outside itself. `Timeline.apply_event/2` takes a timeline and one event and returns the next timeline. The state of a thread after a hundred events is that function applied a hundred times, which is a fold, in the sense of lesson 6 of the Elixir course:

    timeline = Enum.reduce(events, Timeline.new(), &Timeline.apply_event(&2, &1))

A function of this shape, `(state, event) -> state`, is a **reducer**. A value computed from a list of events this way is a **projection** of them: one particular view of what happened, of which there could be others. The timeline is the projection that a chat screen needs. Its items are plain maps of kinds `user`, `assistant`, `thinking`, `tool`, `plan`, `approval`, `turn_end` and `notice`, with string keys, so the same value can be written to disk as JSON and drawn by either front end.

Most of the module is one function clause per event type. Streamed text is appended to the last item if that item is the same kind of text in the same turn, so that hundreds of small `output_text_delta` events become one message. A `tool_call` adds an item, and a later `tool_result` with the same call id updates it. An `approval_requested` adds an approval item with status `pending` and the next letter:

::: example id=fig-label
title: Stratta: core/lib/stratta/timeline.ex
```elixir
  def approval_label(n) when n < 26, do: <<?a + n>>
  def approval_label(n), do: approval_label(div(n, 26) - 1) <> <<?a + rem(n, 26)>>
```
caption: The letter for a thread's n-th request: `a` to `z`, then `aa`, `ab`, and so on. The count only rises, so a letter is never reused within a thread, and that is what makes `2a` a name and not a position.
:::

When a turn ends, any request of that turn still pending is marked `expired`: the agent is no longer waiting for it.

The arrangement is called a **pure core** with a process shell around it, and the repository uses it deliberately. The core (`Timeline`) can be tested by building a list of events and comparing values; no agent, timer or socket is involved, and the test cannot be flaky. The shell (`ThreadServer`) is then small enough to read: it receives messages, calls the core, saves, and broadcasts. The terminal client is built the same way, with `Stratta.TUI.Render` and `Stratta.TUI.Keys` as pure modules, and two plans add more: the composer plan's `Stratta.TUI.Composer` and the command parser of the app-first plan are both specified as pure modules for this reason.

One qualification, so that the word is not oversold. `Timeline` stamps each new item with an id and a time, and takes both from the system. It is pure in every way that matters for testing a sequence of events, and not in the strict sense.

::: note
Lab 3 (`exercises/03_timeline.exs`) is a small timeline. One of its tests states the property that makes a fold safe to resume: folding the first *k* events and then the rest gives the same state as folding them all, for every *k*. Its last function, `evidence/2`, comes back in [[s26]].
:::

::: example id=fig-lab3
title: The resume property, from the lab's tests
@file elixir solutions/03_timeline.exs | test "folding in two pieces | assert resumed == whole +2
caption: If this holds, a process that crashes and reloads the state it had saved can carry on from the next event.
:::

### 12. Events, sequence numbers and what survives a restart

An event from Harness carries a type, the turn it belongs to, a payload, and a **sequence number** that only increases within one session. Sequence numbers let a reader say where it has got to. ThreadServer's follower asks for the stream "from cursor 0", meaning from the beginning; a **cursor** is a reader's position in a sequence, and a reader that keeps one can stop and resume without missing or repeating anything.

Harness keeps a session's events, but not for ever and not across a restart. Its documentation is direct about both: retention is bounded, and runs and sessions do not survive a restart of the virtual machine or the host. If a reader asks for events that have already been discarded, the stream says so with a `replay_gap` event, and the timeline shows a notice.

So there are two places a thread's history could live, and Stratta has to be clear which one it trusts.

An **event log** is the full ordered list of events, kept as the record; state is whatever you get by folding it. A snapshot is the state itself at some moment, saved so the fold need not be repeated. Stratta keeps the snapshot and not the log. `Stratta.Store` writes `state.json`, holding projects and thread records, and one `threads/<id>.json` per thread holding that thread's timeline items. A restarted ThreadServer loads the items; it does not replay events, because the events are gone.

This has a consequence that the decision-records plan runs into at once. The timeline is a projection, and a projection has already thrown away whatever its screen did not need. The plan's first phase is a question about exactly this: can the list of things that led up to a request be recovered from the timeline *as it is stored*, or does the fold need to keep something more ([[s26]])?

A second consequence was found on 26 November 2026, by running the timeline module by itself, and repaired the next day. A timeline item's id is the letter `i` and a number. At the commit this tutorial describes, the number came from a counter that belongs to the running virtual machine and starts again at 1 when it starts. Within one run of the daemon every id was new. After a restart, the first new item in an old thread was `i1` again, and an update is addressed to an id.

::: example id=fig-ids
title: The timeline module across a restart, before the repair
@file text research/verify/timeline-ids-before.txt | $ elixir -r stub.exs -r core/lib/stratta/timeline.ex run2.exs items.bin | user message, after the run
caption: A second run of the virtual machine loads three saved items and folds in one tool call and its result. The tool call takes the id of the user's message, and the result is written into both. Only `timeline.ex` was loaded, as it stood before the repair, on an older Elixir than Stratta requires.
:::

The request letters of [[s11]] never repeated, and the reason is worth noticing: when a timeline is loaded, the next letter is worked out from the stored items. Nothing did the same for ids.

The repair does the same for ids. The timeline now counts its own items, and loading one carries the count on from the highest stored id. A stored item whose id an earlier item already has is given the next number.

::: example id=fig-ids-after
title: The same two runs, after the repair
@file text research/verify/timeline-ids.txt | $ elixir -r stub.exs -r core/lib/stratta/timeline.ex run2.exs items.bin | user message, after the run
caption: The new tool call is `i4`, no id repeats, and the user's message is as it was loaded. `scripts/check_timeline_ids.sh` produces this and fails if an id repeats. The repair was tested with this one module loaded by itself; Stratta's whole suite has not been run on the versions it requires since.
:::

The plan that describes the repair, *Ids that survive a restart, and a log of events*, has a second part, which is a proposal: the thing this section said Stratta does not keep. A file of events for each thread, appended and never rewritten, each line carrying a number that is never reused in that thread. The timeline would stay as the snapshot. A decision's evidence could then point at lines that cannot change afterwards, an event that arrived in the moment before a shutdown would not be lost, and a timeline could be folded again when the fold changes. The price is disk, and a second thing that has to agree with the first. None of that part is scheduled.

What survives a daemon restart, then, is the thread record, its slot, and its timeline. What does not is the agent's live session and any request that was waiting. Where a provider supports resuming a conversation, the thread record keeps the provider's own session id, and the next message to the thread starts a new Harness session that asks the agent to load the old conversation.

### 13. PubSub: topics and subscribers

A ThreadServer does not know who is watching its thread. It might be nobody, or a dashboard, two viewers and a browser tab. **Publish and subscribe**, PubSub for short, is the pattern that keeps it from having to know: a process that is interested subscribes to a named **topic**, and a process with news broadcasts a message to the topic, which delivers it to whoever is subscribed at that moment.

Stratta uses the `Phoenix.PubSub` library, started as the first child of the tree. Underneath, it is the Registry of [[s9]] used the other way round: keys may repeat, each subscriber registers itself under the topic's name, and a broadcast looks the topic up and sends the message to every process found. Because registry entries vanish when their process exits, a viewer that is closed or a browser tab that is shut needs no unsubscribing.

There are three topics.

| Topic | Message | Sent when |
|---|---|---|
| `thread:<id>` | `{:thread, id, snapshot}` | anything about that thread changes |
| `threads` | `{:thread_status, id, status, thread}` or `:threads_changed` | a thread's status, record or waiting requests change; a thread is added or removed |
| `current` | `{:current, workspace, thread_id}` | a workspace's current thread changes |

The subscribers are of two kinds. In the app, each open page is a process (a LiveView), and it subscribes to `threads` and to the topic of the thread it is showing. For the terminal, each socket connection is a process in the daemon, and it subscribes on behalf of the client at the other end ([[s15]]).

The first two topics exist separately for a reason of volume. A thread that is streaming text changes many times a second, and the thread list shows none of that text. So ThreadServer broadcasts to `threads` only when what the list shows has changed:

::: example id=fig-broadcast
title: Stratta: core/lib/stratta/thread_server.ex
```elixir
  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Stratta.PubSub, topic(state.id), {:thread, state.id, snapshot_of(state)})
    sig = {status_of(state), state.thread, pending_of(state)}

    if sig == state.list_sig do
      state
    else
      Phoenix.PubSub.broadcast(Stratta.PubSub, "threads", {:thread_status, state.id, status_of(state), state.thread})
      %{state | list_sig: sig}
    end
  end
```
caption: Every change goes to the thread's own topic. The list hears only when the triple of status, record and waiting requests differs from the last one it was told.
:::

::: note
Lab 4 (`exercises/04_pubsub.exs`) writes publish and subscribe on a Registry in about ten lines, then the coalescer of the next section.
:::

### 14. Snapshots, and pushing no faster than a client reads

Two design choices in the announcing are easy to miss and matter to the plans.

**Whole state, not changes.** Each message on a thread's topic carries the entire snapshot: the thread record, every timeline item, the status, the model in use, the usage figures. A subscriber needs no history to make sense of it and cannot get out of step, because every message replaces everything it knew. The cost is size, since a long thread is re-sent in full on every change. Sending only what changed (a **delta**) would be smaller and would need every subscriber to apply changes in order without missing one.

The plans accept this choice and work around its cost where it shows. The slash-commands plan puts an agent's command list in the thread's snapshot and deliberately keeps it out of the thread list. Code mode exists partly because a three-thousand-line diff should be read by a script and summarised, not placed in a model's context ([[s32]]).

**Coalescing.** A terminal over a slow connection cannot draw a hundred frames a second, and should not be sent them. The connection process in the daemon does not forward each snapshot as it arrives. It keeps only the latest snapshot for each thread and sets a timer of 40 milliseconds; when the timer fires it sends what it is holding. A burst of fifty changes becomes one push carrying the fiftieth state. Merging a burst into its last value is **coalescing**, and it is safe here only because of the first choice: the last snapshot contains everything the earlier ones did.

::: example id=fig-queue
title: Stratta: core/lib/stratta/socket.ex
```elixir
  defp queue(st, key, value) do
    timer = st.timer || Process.send_after(self(), :flush, @flush_ms)
    %{st | pending: Map.put(st.pending, key, value), timer: timer}
  end
```
caption: The whole of the coalescer's bookkeeping. `Map.put/3` overwrites the pending value for the same key, and the timer is set only if none is running. It is the debounce of section 6 with a map in place of a flag.
:::

This is also a mild form of **back-pressure**, the general name for a slow consumer limiting a fast producer. Here the producer is not slowed down; the daemon simply never queues more than one pending state per thread for a client, so a slow client costs a bounded amount of memory.
@@part 4 | The edges of the node | the socket, the operations, other programs, two agent protocols and the terminal

### 15. The control socket

The terminal client and the daemon are separate programs on one machine. They talk through a **Unix domain socket**: a socket that is named by a path in the file system and reachable only from the same machine. Stratta's is `stratta.sock` in the data directory. Nothing is opened on the network.

Because the socket is a file, the file's permissions decide who may connect. The daemon sets them to owner-only as soon as it starts listening:

::: example id=fig-listen
title: Stratta: core/lib/stratta/socket.ex
```elixir
{:ok, listen} <- :gen_tcp.listen(0, [:binary, packet: 4, active: false, backlog: 64, ifaddr: {:local, path}]) do
  File.chmod(path, 0o600)
```
caption: The listening call. `ifaddr: {:local, path}` makes it a Unix socket at that path. Mode `0o600` means the owner may read and write and nobody else may do anything. Today this line is Stratta's entire access control.
:::

A socket delivers a stream of bytes with no boundaries in it; one `send` of a thousand bytes may arrive as three reads. A protocol on top needs **framing**, a rule for where one message ends and the next begins. Stratta's rule is a **length prefix**: each message is preceded by its length as a four-byte integer. The option `packet: 4` in the excerpt asks the runtime to do this on both ends, adding the prefix on send and delivering only whole messages on receive, so the Elixir code never sees a partial one. Inside each frame is a JSON object.

A request carries an `id`, an operation name `op` and arguments `args`. The reply carries the same `id` and either `ok: true` with a result or `ok: false` with an error message. The id is how a client matches replies to requests, a technique called **correlation**, and it is needed because the daemon also sends frames nobody asked for at that moment: after a `subscribe`, the daemon pushes an `event` frame whenever the subscribed thing changes. A client waiting for reply 7 must be ready to receive three pushes first.

On the daemon's side the socket is three layers of processes, each a use of something from [[p2]]. One GenServer owns the listening socket. A linked helper loops accepting connections. Each accepted connection becomes a task that owns that client's socket, subscribes to PubSub topics on its behalf, coalesces what it hears ([[s14]]) and runs each request in a further task ([[s10]]). The connection asks for its data with `active: :once`: the runtime delivers one frame as a message and then waits to be asked again, which keeps a client that floods the socket from flooding the connection's mailbox.

Two details guard the data directory. On starting, the daemon tries to connect to any socket file already there. If something answers, another daemon owns this directory and the new one refuses to start, since two would overwrite each other's files. If nothing answers, the file was left by a crash and is removed.

::: note
Lab 5 (`exercises/05_socket.exs`) is a socket server and client with the same framing, ids and pushes. Its last test turns the framing off on one end to show the four bytes.
:::

### 16. Stratta.API: a closed set of named operations

Behind the socket is one module, `Stratta.API`, and it is the most important boundary in the plans.

An **operation** is a named thing the daemon can be asked to do, with arguments and a result that are JSON-shaped: maps, lists, strings, numbers. There are twenty-one today, among them `threads.create`, `thread.send`, `thread.approve`, `thread.diff`, `thread.ship`, `thread.handoff`, `current.set` and `ping`, and the socket adds `subscribe` and `unsubscribe`. The set is closed: an unknown name is an error, and there is no way to ask the daemon for anything that is not on the list.

Every operation returns `{:ok, result}` or `{:error, message}`, and the module guarantees it at the single entrance:

::: example id=fig-call
title: Stratta: core/lib/stratta/api.ex
```elixir
  def call(op, args \\ %{}) do
    case run(op, args || %{}) do
      {:ok, _} = ok -> ok
      :ok -> {:ok, %{}}
      {:error, reason} -> {:error, ThreadServer.format_error(reason)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  catch
    :exit, {:timeout, _} -> {:error, "The daemon took too long to answer."}
    :exit, reason -> {:error, "Failed: #{inspect(reason)}"}
  end
```
caption: The one way in. Whatever `run/2` does, raise, time out waiting on a ThreadServer, or return an error, the caller gets a tagged tuple with a sentence in it.
:::

Each operation's body is a `with` chain in the style of lesson 8: resolve the thread, check the precondition, do the thing, shape the result, and fall out at the first step that fails with that step's message. `thread.approve` shows the care taken over names. Its argument may be a thread or a request name; `2a` is split into slot 2 and letter `a`; and a letter that has already been answered is refused with "2a was already approved", never quietly redirected to a newer request.

Why this module matters so much to the plans:

- *The app first* decides that everything the app does will go through these operations, which is what makes a daemon on another machine usable ([[s35]]).
- *Code mode* gives every operation a written **spec**: its arguments, its result, one line of description, and whether it only reads. Three later things are generated from the specs ([[s31]]).
- *Remote access* describes a remote transport as "a second listener onto the same API".
- *Authority* attaches a grant to the operations that answer requests ([[s29]]).

A closed set of named operations with data in and data out is what all four need. A set of Elixir functions called directly, which is what the app uses today, could give none of them.

### 17. Other programs: ports and the process helper

An agent is not Elixir code. It is another program, often written in another language, that must be started, fed input, read from, and stopped, along with any programs it starts in turn.

The runtime's mechanism for this is the **port**. The BEAM Book's chapter on input and output calls a port the "process-like interface" between Erlang processes and everything that is not one: a program started through a port looks, from Elixir, like something you send messages to and receive messages from. Its output arrives in the owner's mailbox, and so does its exit status.

The alternative is to load foreign code into the virtual machine itself, as a **NIF** (a native implemented function). The Book's chapter on interfacing other languages is clear about the trade: a program behind a port runs in its own operating-system process, so its crash cannot bring down the node, while native code inside the node can. For a control plane whose whole purpose is to outlive the agents it runs, the choice makes itself. Every agent is a separate program.

A bare port is not quite enough for agents, though. An agent starts children of its own (a shell, a test runner, a compiler), and stopping the agent must stop all of them. That needs a **process group**, an operating-system grouping that lets a signal be sent to a program and its descendants together. Some programs also insist on being attached to a terminal ([[s20]]). Jido.Harness therefore ships a small native *helper program*, built from C++ when Harness is compiled, which runs beside the node and does the starting, grouping, signalling and terminal work on Harness's behalf. This is why building Stratta needs a C++ compiler, and why the README notes that the helper refuses to run as root.

One limit of this arrangement shapes a plan. A program started through a port has its input and output connected to the node, not to the operator's terminal. An Elixir program cannot step aside and give its own terminal to a child. The pane-threads plan, which wants an agent's real interface in the operator's terminal, therefore has `stratta run` print a command and lets a few lines of shell start the agent with `exec`, which *replaces* the shell with the agent and so hands over the terminal.

::: note
Lab 6 (`exercises/06_port.exs`) opens a port to a twelve-line shell script that plays an agent, including a permission request that holds its turn until answered.
:::

### 18. ACP: what an agent speaks in protocol mode

Most coding agents can run in two ways. Interactively, they draw their own interface in a terminal. In *protocol mode* they draw nothing, and exchange structured messages with whatever program started them. A thread in which Stratta runs the agent in protocol mode and draws everything itself is a **headless thread**. Every thread is headless today.

The protocol is the **Agent Client Protocol**, ACP. The program that starts the agent is the *client* (here, Harness inside the daemon) and the agent is the *agent*. Messages follow **JSON-RPC**, a small convention in which a request is a JSON object with a method name, parameters and an id, a response carries the same id, and a **notification** is a request with no id, to which no response is expected. The messages travel over the agent's standard input and output.

The methods a reader of the plans needs are few:

| Direction | Method | Meaning |
|---|---|---|
| client to agent | `initialize` | agree a protocol version and what each side can do |
| client to agent | `session/new`, `session/load` | start a conversation, or resume one |
| client to agent | `session/prompt` | the user's message: begin a turn |
| agent to client | `session/update` (notification) | progress: text, thinking, a plan, a tool call and its result |
| agent to client | `session/request_permission` | may I do this? The agent waits for the response |
| client to agent | `session/cancel` | stop the current turn |

The fifth row is the one this tutorial began with. A permission request is a JSON-RPC request *from the agent to the client*. The agent's turn is suspended on the response, which is why answering can take as long as the operator likes, and why "who is allowed to produce that response" is a question worth three plans.

`session/update` has kinds. One of them, `available_commands_update`, carries the list of **slash commands** the agent offers: each has a name, a description and an optional hint for its input, and the list may be sent again whenever it changes. A command is run by sending an ordinary prompt whose text begins with `/name`. Stratta already passes prompt text through untouched, so commands work today; what is missing is that the list arrives and is dropped. That is the whole of the slash-commands plan.

Harness sits between this protocol and Stratta. It uses a library, Arbor ACP, for the encoding and the matching of ids, and turns what arrives into the events of [[s12]]. It gives Stratta a `Jido.Harness.Session` with a handful of functions: start, send a message when idle, queue a follow-up when busy, steer, interrupt, answer a permission request, change a setting, read the event stream. Each provider is described to Harness by an **adapter**, a module saying how to find and start that agent and which optional features it has (resuming, steering, switching model mid-thread). Stratta asks the adapter before offering a feature, which is why the app's controls differ from agent to agent. The bundled demo agent is one more adapter, pointing at a scripted Python program that speaks ACP and is not a model.

### 19. Hooks: the agent's own interface, reporting in

Protocol mode gives Stratta full structure and loses the agent's own interface, with its commands, pickers and layout. Some agents offer a second way for an outside program to take part, which keeps the interface.

A **hook** is a command the agent runs at a named moment in its own work, passing a description of the moment as JSON on the command's standard input and, for some moments, reading a decision from its output. Claude Code has many such moments; the ones the pane-threads plan uses are session start and end, prompt submission, stop, and `PermissionRequest`, which runs when the agent is about to ask for permission. A `PermissionRequest` hook may print a JSON object whose `hookSpecificOutput.decision.behavior` is `allow` or `deny`. If it prints no decision, the agent's normal dialog proceeds as if the hook were not there.

A **pane thread** is the plan's name for a thread built on this. The agent runs in a terminal pane the operator opened, drawing its own interface. Its hooks are set, for that run only, to a short command, `stratta hook <event>`, that forwards each event to the daemon over the control socket. For a permission request the hook does not return at once: the daemon records the request as `2a` like any other and holds the hook's call open until somebody answers, or until a wait just short of the hook's own time limit runs out, in which case the hook reports no decision and the agent's dialog takes over.

| | Headless thread | Pane thread |
|---|---|---|
| Who starts the agent | the daemon | the operator, in a pane |
| What the agent speaks | ACP, over standard input and output | its own interface; hooks call out |
| The request is held by | Harness, inside a turn | a hook command, waiting on the socket |
| Timeline in Stratta | complete | partial, built from hook events |
| Send and steer from Stratta | yes | not at first: hooks cannot type |
| Survives closing the terminal | yes | no |

The plan says plainly that one unknown decides its design: what the person at the pane *sees* while a hook is holding a request. If the agent shows its own dialog at the same time and the first answer wins, both places work. If the dialog appears only after the hook returns, holding the request freezes the pane, and a pane thread needs a rule for how long to hold. Step [[step:pane-threads-0]] of `next.md` is the experiment that answers this, and it needs a machine with the agent installed and signed in, which is why it is marked as blocked on the operator.

Two properties carry over unchanged from headless threads, by design. A pane thread produces the same snapshot shape, so every front end shows it without knowing the difference. And a failing hook must never approve: an error or a timeout yields "no decision".

### 20. Terminals: escape sequences, raw mode and pseudo-terminals

Three plans are about the terminal client, and one is about putting a terminal inside the app. They need four ideas.

A terminal is a device that receives bytes and draws characters. Most bytes are characters to draw. Some sequences, beginning with the escape character, are instructions instead: move the cursor, set a colour, clear the screen. These are **escape sequences**. One family, the **OSC** sequences (operating system command), carries data to the terminal program itself and draws nothing. A terminal that does not know a sequence discards it, which is why a program can emit new ones without asking who is listening. Stratta's viewer already emits two to report an agent's state to the terminal it runs in (numbered 7501 and 9;4). The hyperlinks plan adds **OSC 8**, which marks a span of text as a link to a URL that is not itself displayed.

Normally a terminal collects a line and hands it to the program when Enter is pressed, and interprets some keys itself (ctrl-c interrupts). A full-screen program needs every key as it is pressed. Switching the terminal to deliver them is entering **raw mode**. `Stratta.TUI.Term` does this, moves to the terminal's alternate screen so the previous contents return on exit, and starts a process that reads input and forwards it as messages. The client's main loop (`Stratta.TUI.App`) is then one `receive`: keys from the terminal, frames from the daemon, a tick to notice a resize; after each, it asks the current view to render and writes the result only if it differs from what is on screen.

The third idea is that *width is not length*. `Stratta.TUI.Render` builds each row as a list of styled spans and measures text by counting characters, one cell each. That is why the hyperlinks plan represents a link as an annotation on a span rather than as bytes inside the text: an escape sequence has length and no width, and if it were in the text, the function that truncates a row to fit could cut a sequence in half and leave the rest of the pane a link. It is also why the composer plan keeps its cursor as a **grapheme** index (a grapheme is what a reader sees as one character, however many code points encode it), and why both plans leave wide characters, which occupy two cells, as a known limit to be fixed in one place later.

The fourth is the **pseudo-terminal**, or PTY: a pair of connected endpoints provided by the operating system, one of which behaves like a terminal to the program attached to it, while the other is read and written by a controlling program. It is how a terminal emulator, or `ssh`, runs a shell that believes it has a real terminal. The app-first plan's shell is this: a process in the core owns a PTY with the operator's login shell on one end, started through the Harness helper ([[s17]]), keeps a bounded scrollback, and exposes input, output and resize as operations and a subscription, so that a terminal widget in the page, or `stratta shell` in a terminal, can attach to it.
@@part 5 | Behaviours and Jido | contracts between modules, and the framework the first integration is built on

### 21. Behaviours: a contract a module signs

Several plans contain a sentence of the form "X is a behaviour with two implementations". The word has a precise meaning in Elixir.

A **behaviour** is a list of functions, with their argument and result types, that a module may promise to provide. The list is written once, in the module that defines the behaviour, as `@callback` lines. A module that makes the promise says `@behaviour TheBehaviour`, and the compiler warns if any promised function, a **callback**, is missing. Marking each one `@impl true` makes the promise checkable in the other direction too: the compiler objects if a function marked that way is not in any behaviour's list.

A behaviour is what lets code be written against a contract without knowing which module will fulfil it. The calling code holds a module name as a piece of data, from configuration or from a record, and calls `module.function(args)`. This is Elixir's form of an interface.

Stratta already depends on four.

- `GenServer` and `Application` are behaviours. `use GenServer` signs the contract and supplies defaults; `handle_call/3` and the rest are its callbacks.
- `Jido.Harness.Adapter` is the behaviour every provider implements ([[s18]]). `Stratta.DemoAdapter` signs it and provides `spec/0` and `status/1`. Adding a provider means writing one such module and naming it in configuration; nothing else in Stratta changes. The plans use the phrase "configured in, the way a provider is" for exactly this.
- The terminal client's views follow a contract that is written down in a comment and not declared: a view is any module with `init`, `key`, `frame`, `render`, `status`, `emit` and `leave`. The dashboard, the viewer and the diff view are three such modules, and the loop of [[s20]] runs any of them.

The plans add four more, and seeing them as one move makes the plans easier to read.

| Planned behaviour | The contract | Implementations |
|---|---|---|
| `Stratta.Authority` | one question: may this grant answer this request this way? | local (a secret in the data directory); external (a verifier outside Stratta) |
| `Stratta.Environment` | create, destroy, run the agent, attach a terminal, read a diff, checkpoint | local (today's worktree and child process); others, kept outside the repository |
| the app's client layer | call an operation, subscribe to a thread | the daemon in the same node; a daemon behind a socket |
| the thread itself | keep a timeline, answer `respond_approval`, broadcast a snapshot | `ThreadServer` (headless); `PaneThread` (hooks) |

In each case the plan first *names what exists* as one implementation of a contract, changing nothing the operator can see, and only then adds a second. The environments plan says so in as many words: its refactoring phase is finished "when every existing test passes" with nothing else altered. That order is what keeps a large change reviewable, and it is why several plans have a phase that appears to do nothing.

::: note
Lab 7 (`exercises/07_authority.exs`) defines a one-question behaviour and a local implementation of it. The rest of the lab belongs to [[s28]] and [[s29]].
:::

### 22. Jido in one section: values, signals and turns

**Jido** is a framework for building agents on the BEAM. "Agent" here is wider than "coding agent": it means any long-lived thing that receives messages, holds state, and decides what to do. The policy plan uses Jido for one narrow job, and to follow that plan a reader needs six of Jido's ideas. They are described here as they stand in Jido's version 3 guides, which are a beta at the time of writing; [[s40]] notes where the plans' wording predates them.

**An agent is a value.** A `Jido.Agent` is an immutable struct: a definition (its state schema, its routes, its plugins) plus an id and a state. Creating one starts no process. Running it is a function: `cmd/3` takes the agent and a message and returns a new agent and a list of effects. The old value is untouched. This is the pure core of [[s11]] made into the framework's central rule.

**A signal is the one kind of message.** Everything an agent receives or sends is a `Jido.Signal`, an envelope with a `type` such as `"order.place"`, a `source`, an id and a `data` payload. The envelope follows **CloudEvents**, a public specification for describing events in a common way, so the fields are not Jido's invention.

**An action is a unit of work with a validated input.** A `Jido.Action` is a module with a name, a schema for its parameters, and a `run/2` function that receives the validated parameters and a context and returns a result. An agent's **routes** say which action handles which signal type.

**A turn is one signal, handled.** Jido's turn is a different thing from a coding agent's turn in [[s1]], and the two should not be confused: here it means one evaluation of one signal by one agent.

**A directive is an effect, described and not yet performed.** An action that wants something to happen in the world, a signal emitted, a reply sent, a child started, the agent stopped, does not do it. It returns a **directive**, a struct that says what should happen, and the runtime performs it later. The description can be inspected, tested and logged before anything occurs. The policy plan singles this out: "a decision can be inspected before it happens".

**The commit divides a turn.** On a live agent, a turn first produces a *candidate*: the complete next agent value and an ordered batch of directives, visible to nobody. Any failure up to that point discards the candidate and the agent is exactly as it was. Then the runtime **commits**: it replaces the agent with the candidate. Only after that is the caller answered, and only then do the directives run. An effect that fails cannot undo the commit.

::: diagram id=fig-turn file=turn.svg
One Jido turn on a live agent. Everything to the left of the line can fail without trace. Nothing to the right can be taken back.
:::

The live form is an **AgentServer**, a process that holds an agent value and replaces it at each commit. It is built on `:gen_statem`, OTP's state-machine relative of GenServer, and it sits inside a small supervisor of its own that Jido calls an activation. Everything in [[p2]] applies to it: it is found by id and not by pid, it hands slow work to tasks, and a crash loses the turn in progress but not the last commit.

The reason a reader of Stratta's plans should care is the fit. Stratta already has values folded from events, effects pushed to the edge, and processes that only own and decide. Jido makes those three habits into rules the framework enforces.

### 23. Plugins, which the plans call skills

The policy plan and the behaviour-shaped UI plan both lean on a Jido feature they call a **skill**: "behaviour modules with their own slice of state and a schema that merges into the agent's". A reader who opens Jido's current guides to look this up will not find it under that name, so the correspondence needs stating.

In Jido version 3 the feature is the **plugin**. A plugin is one module that adds a complete capability to an agent through optional callbacks. The ones that matter here:

- `state_spec/1` declares one field of the agent's state that the plugin owns, with its schema. Jido rejects a turn in which an ordinary action changed a plugin's field. This is the "own slice of state".
- `reduce/2` computes the next value of that field after each turn.
- `admit/3` runs before a turn on a live agent and may reject it.
- `after_commit/3` observes each committed turn.
- `directives/1` and `dispatch/4` let a plugin define directive types of its own and be the one that performs them.
- `child_spec/1` lets a plugin have a supervised process that lives as long as the agent.

In version 3 the word "skill" means something else: a `SKILL.md` file of instructions that an AI agent can load as a tool. So where a plan says "a policy skill holds its rules", read "a policy plugin owns a field holding the rules".

The property the behaviour-shaped UI plan wants survives the renaming. Because a plugin's state carries its own schema, a screen can draw a card for state it was never written for: the fields from the schema, the values from the state, and edits sent back as signals to the plugin's own actions ([[s31]]).

One plugin in particular matters to Stratta. Harness ships `Jido.Harness.Plugin`, which connects one live agent to one coding-agent conversation. Commands to the agent are signals of types beginning `jido.harness.command.` (prompt, interrupt, answer an approval), and what the coding agent does comes back as signals such as `jido.harness.approval.requested`. The plugin uses `child_spec/1`: it starts a process that *owns the Harness session* for as long as the agent is live. That sentence is the subject of the next section.

### 24. Who owns the session: Route A and Route B

Stratta's README lists, as its first next step, wrapping each thread in a Jido agent so that approval policy becomes Jido actions. The policy plan is that work, and it turns on one fact about ownership.

A Harness session is held by one process. Today that process is the thread's ThreadServer. `Jido.Harness.Plugin` is written to hold it too, in the process it starts for each live agent. Two owners of one session is not a configuration; it is a contradiction. So there are two ways to bring Jido in, and they are different designs, not points on a scale.

::: diagram id=fig-routes file=routes.svg
The two routes. The session has one owner in each. What changes is which process that is, and therefore which code has to be rebuilt around it.
:::

**Route A, policy only.** ThreadServer keeps the session and everything else it does. A plain Jido agent, without the Harness plugin, sits beside it and holds only the rules and their state. When a permission request arrives, ThreadServer asks the agent, and the agent answers allow, deny or ask. In the plan's words a rule set is "a pure function from a request plus thread state to an answer". Nothing about the timeline, the store, slots or the socket changes. If the experiment disappoints, it is removed and nothing else notices.

**Route B, the plugin owns the thread.** The Jido agent with the Harness plugin becomes the thread. ThreadServer stops holding a session and becomes a client of the agent: it sends command signals and receives result signals. The plan lists what gets easier (threads that start threads, scheduled wake-ups, a thread's life declared as a state machine) and what it costs: the timeline, the store, the slots and the socket API would all be re-fitted around a runtime Stratta does not control. Since 26 November the plan adds that some of that list may not need Route B, because of the machinery in [[s25]], and that this is unverified.

The plan's instruction is to do Route A first and not to decide Route B until A has run. Its phases follow from that.

- *Phase 0* asks only whether to take the dependency: build the core with `jido` added and nothing else changed, and record what comes with it and whether anything behaves differently. `Jido.Harness.Plugin` is compiled only when Jido is present, so adding the dependency also brings that module into existence, which is part of what the phase checks.
- *Phase 1* builds the rules with no Jido in them at all ([[s28]]).
- *Phase 2*, only if Phase 0 said yes, expresses the same rules as actions in an agent with the rules' state in a plugin. It is finished when Phase 1's tests pass unchanged, which is the behaviour pattern of [[s21]] again.
- *Phase 4* is writing only: with A run, set down what B would cost and unlock.

A reader should come away with a way to evaluate Route A when its results arrive. The claim under test is that expressing policy as actions and directives buys something a plain matching function does not: rules whose arguments are validated by a schema, rule state that a screen can draw unseen, and answers that exist as inspectable values before they take effect. If Phase 2 delivers the same behaviour as Phase 1 and none of those three turns out to be used, the finding to report is that the discipline did not pay, and the plan is written so that such a finding is cheap.
### 25. Flows, waits and a blackboard: the rest of Jido

[[S22]] to [[s24]] cover the part of Jido that the policy plan uses. Jido's version 3 has more, and since 26 November 2026 two plans say so: the policy plan gained a section called *What else Jido has*, and a plan about graphs ([[s34]]) rests on it. What follows was read in Jido's guides and source at the same commit as [[s22]]. None of it was compiled or run, and Jido's README says that its APIs can change during the beta.

**A flow is a graph written as data.** A `Jido.Flow` is a named set of parts. Each part names an action and says where its parameters come from: the flow's input, or the result of another part. The flow holds no code of its own. Jido works out the order from those references, so a part runs when the parts it reads have finished, and the order in which they are written means nothing. The parts are `step` (call one action), `choice` (the first option whose condition holds), `map` and `reduce` (over a list), `parallel`, `iterate` (a loop with a bound), `invoke` (choose the target while running), `handoff`, and three that wait.

Because a flow is a value and not a program, it can be examined before it runs. A reference to a part that does not exist, or a cycle, is a compile error at the line that wrote it. A flow has an identity, a hash of what it means. It can be stored as JSON, in which each action is named by an id and a version that a catalog of registered actions resolves, and its conditions are written in a small language of expressions that are data and are never run as code.

To run a flow, Jido compiles it to a graph for **Runic**, a separate library for dataflow that Jido requires. Runic's own version is an alpha.

**A wait holds no process.** Three parts suspend a flow: `await` for one matching event, `timer` for a delay, and `selection` for the first of several. A waiting flow saves its position and gives up its worker, so a wait can outlast a restart. Jido's guide gives an example whose shape a reader of this tutorial has already met.

::: example id=fig-flow-wait
title: Jido: guides/flow-runtime/flow-waits.md
```elixir
    selection "review" do
      await "approved", event: "refund.approved", match: %{refund_id: input(:refund_id)}
      await "rejected", event: "refund.rejected", match: %{refund_id: input(:refund_id)}
      timer "expired", after_ms: 3_600_000
    end
```
caption: A flow waiting for a reviewer to approve or reject, or for an hour to pass. A permission request in Stratta has the same three ways out: allowed, denied, or expired when its turn ends ([[s11]]).
:::

A wait needs somewhere to be saved, and Jido offers two hosts that provide it. One is a live agent started with a store. The other is a **durable run**: `Jido.Durable` runs a stored flow, takes its input as signals, and saves at the boundary of each part. Its documentation describes it as independent of agents and of AgentServer. It needs a named Jido instance and a store, and the stores include one that writes files for a single virtual machine. It owns no clock: a host that wants a timed wait to fire calls it again at the time the run reports.

That bears on [[s24]]. Route B's list of what gets easier includes waiting and resuming. If a durable run needs no AgentServer, some of that list is within reach while ThreadServer keeps the session. The graphs plan asks for this to be tried with the build that policy Phase 0 makes: one flow whose actions call `Stratta.API`, run durably with the file store. One part of the answer is known in advance, and it is not Jido's to fix. An agent's conversation ends with the virtual machine ([[s12]]), so a flow that wakes after a restart finds its thread's session gone, and what it should do then has to be designed.

Three more pieces, briefly.

A **topology** is an agent's declaration of member agents that start when it starts, with connections that route one member's output signals to another. It is Jido's own way of arranging several agents.

A **blackboard** is a named board of values that several parties read and change. In Jido a reader takes a snapshot with a revision, and a change is a patch that is refused if the revision has moved. That is optimistic concurrency, which [[s35]] meets again for files.

And there are statecharts written in SCXML, behaviour trees, a thread value that only grows, and a trace value in the W3C form.

A reader should hold two things together. This is most of what a system for arranging agents needs, already written, in the language Stratta is written in. And it is a beta resting on an alpha, none of which Stratta has built against. The plans treat it accordingly: one spike, and nothing that depends on it.
@@part 6 | The control plane | the ideas in the plans that are not about Elixir

### 26. A decision as a record

[[s3]] ended by noticing that nothing is written down about a decision. Today three things exist separately: the request (an item in the timeline), the answer (the same item's status), and the events that came before. The plan's phrase for how they are connected is "the join is done by eye".

A **decision record** is one stored value per answered request that makes the join. The plan gives it six parts:

- *the request*: thread, request name, and the agent's own statement of what it wants, as it was shown to whoever answered;
- *the answer*: allow or deny;
- *who answered*: the client that sent the answer, or later the rule that did;
- *two times*: when the request arrived and when it was answered;
- *the evidence*: the ids of the timeline events between the start of the turn and the request;
- *the ground*: the commit the thread started from, its folder and branch, and the agent and model in use.

Three design choices in that list deserve a second look, because later plans depend on each.

**Ids, not copies.** The evidence is a list of references to timeline items, and nothing is duplicated or summarised. A record stays small, and it cannot disagree with the timeline, because it does not restate it.

**Append-only.** Records are added and never changed. A reversal, when the agent-approver plan introduces one, is a new record that refers to the old one. A store that is only ever appended to is an **append-only log**, and it is the simplest kind of store to reason about: what was true when it was written is still there.

**No model writes any part of it.** Every field is either stated by the agent's own protocol or observed by the daemon. The plan calls this "a rule and not a default", and it is the property that the claims plan and the measures plan are built on. A record of what happened, assembled from what the system itself saw, has **provenance**: each part can be traced to where it came from. A summary written afterwards by a model reading a transcript has none.

The plan's first phase is a question, not code, and [[s12]] explained why it has to be asked. The timeline is a projection, kept as a snapshot. Is "the events between the start of the turn and the request" recoverable from it? Lab 3's `evidence/2` answers yes for the lab's small timeline, where every item carries its turn:

::: example id=fig-evidence
title: Evidence as ids, from Lab 3's solution
@file elixir solutions/03_timeline.exs | def evidence(tl, label) do | %{id: id, turn: turn} -> +2
caption: Find the request's item, then collect the ids of the earlier items that share its turn. Whether Stratta's real timeline allows the same query, or loses something in the fold, is what Phase 0 exists to find out.
:::

A decision record is written for requests only. The shell and the editor of the app-first plan act as the operator on real files and produce none. A script or a rule that answers a request is different: that is an automatic answer, and it must name what permitted it.

### 27. Traces and measures

Once decisions are records, a thread has a shape that an existing standard already knows how to describe.

A **trace** is a tree of timed operations that together make up one piece of work. Each node is a **span**: a name, a start time, an end time, a parent, and a set of key-and-value **attributes**. **OpenTelemetry** is the vendor-neutral standard for producing traces, and **OTLP** is its wire protocol for sending them to whatever tool the operator uses to look at them. The standard also publishes *semantic conventions*, agreed names for the attributes of common operations, so that different programs' traces can be read by the same tools.

The telemetry plan's observation is that a thread is already a trace: the thread is the root span, a turn is a span inside it, a tool call is a span inside that, and a decision is a span whose start is the request's arrival, whose end is the answer, and whose attributes include who answered. Exporting that tree costs no screen space in Stratta, since the operator's own tools draw it. The conventions cover model calls and have nothing for a decision, so the decision span's attributes are Stratta's own, and that is the part no general agent-watching tool can produce.

The plan is careful about two things. The exporter is off unless configured through the standard `OTEL_*` environment variables, so nothing leaves the machine by default. And what is exported is structural: prompts and file contents stay behind.

From the spans the daemon derives five **measures**. Each is chosen to be something the operator can act on:

- *Waiting time*: a decision's two times, split into the agent's part and the person's. The plan expects the person's part to dominate.
- *Rework*: a decision reversed, or an edit undone by a later edit.
- *Cost to a decision*: tokens and tool calls spent in the turn that led to a request.
- *Automatic share*: once rules exist, what fraction of requests never reached a person, and how many of those were later reversed.
- *Grounding*: how much of the attached evidence the agent's statement actually refers to.

Only the first is defined well enough to build now, which is why `next.md` schedules the plan's first two phases and leaves the rest waiting on definitions "tight enough to test".

### 28. Policy: rules that answer

**Policy** is the set of rules that may answer a permission request without a person. The plan's design is small, and each line of it is a safety property.

A **rule** matches a request on its shape (the tool, the path, the form of a command) and gives one of three answers: allow, deny, or ask, meaning pass it to a person. Rules are tried in order and **the first match wins**. Three ship, because they are the ones everybody writes first: allow reads inside the working folder, ask for shell commands, deny writes outside the working folder.

**The default is ask.** A request no rule matches goes to a person. More strongly, a rule set that is missing, cannot be parsed, or raises while being evaluated answers nothing at all. A system that falls back to its most cautious behaviour when something is wrong **fails closed**; one that falls back to permitting **fails open**. The same principle governs hooks in [[s19]].

**Every automatic answer names its rule.** The decision record of an automatic answer says which rule fired, and the plan states the converse as a bug: an automatic decision with no named rule.

**Rules live in the data directory, not in the repository being worked on.** The agent can edit files in the repository. A rule set the agent can edit is a rule set the agent can widen.

**No rule may answer a request from a process descended from an agent.** Automatic answers must not become a way round the check in the next section.

Paths need one more idea. "Inside the working folder" has to be judged after the path is **resolved**, turned into the absolute path it actually refers to, because `lib/../../other` begins inside and ends outside. Lab 7's `inside?/2` does the textual part of this. A symbolic link can still point outside while looking inside, which is why the app-first plan's file operations resolve the real path before use and test that case by name.

::: example id=fig-policy
title: First match, default ask, fail closed, from Lab 7's solution
@file elixir solutions/07_authority.exs | def decide(rules, request) do | _error -> {:ask, "rule-error"} +1
caption: The whole evaluator. `Enum.find_value/3` returns the first non-nil result, or its default. The `rescue` covers the entire function, so one broken rule cannot let a later rule answer.
:::

Later phases add "always allow this", which appends a rule and says which one it appended, and a fourth answer, *referable*, which hands the request to a reviewer ([[s30]]).

### 29. Authority: from reaching the socket to holding a grant

**Authority** is the right to have an action taken on your say. Today the authority to answer a permission request belongs to any program that can open the control socket. [[s15]] showed the one line that enforces it.

That is an instance of **ambient authority**: a right that comes from where a program is running and who it is running as, not from anything it holds. The trouble with it is specific and already documented in the repository. An agent runs as the operator. A shell command that an agent has been allowed to run can therefore call `stratta approve` for *another* thread's pending request, or its own. The daemon is being used by one party with the authority of another, which security writing calls a **confused deputy**.

::: diagram id=fig-authority file=authority.svg
The same socket, two models. On the left the daemon cannot tell its callers apart. On the right an answer has to present something the agent's shell does not have.
:::

The plans meet this at two levels.

The first is to check *who is calling*. The operating system can tell a program which process is on the other end of a Unix socket (on Linux, through a socket option called `SO_PEERCRED`), and the daemon can refuse an approval from any process descended from an agent it started. Agents can also be started with a marker in their environment that makes the `stratta` client refuse. The authority plan keeps both and calls them what they are: heuristics.

The second is to make authority something **held and presented**. A **capability** is an unforgeable token that grants a specific right to whoever presents it. The plan's word for one is a **grant**, and it builds up in four steps, paying for cryptography only when a grant has to leave the machine.

1. *A local grant.* A secret in the data directory, readable only by the operator, that every answer must present. A program that merely reached the socket does not have it. This closes the hole and needs no new dependency. It is also the login that the app needs before it may open a shell in a web page: the app-first plan and this one agree to build one token, not two.
2. *Narrowing.* A grant that names what it may answer (these tools, this thread, this folder, until this time) and that can be handed on only as something strictly weaker. Making a weaker token from a stronger one is **attenuation**, and it is what makes delegation to anything other than the operator expressible at all.
3. *Signing.* An answer that carries proof of who gave it, with the key held by the operator and not by the daemon.
4. *Across machines.* Grants that a daemon can verify without having issued them.

Steps 2 to 4 are what an existing open specification, **Biscuit**, provides: a token verified with a public key, which its holder can attenuate offline by appending restrictions that cannot afterwards be removed. The plan's position is that Stratta should depend on neither Biscuit nor a signature library. It defines the `Stratta.Authority` behaviour of [[s21]], ships the local implementation, and lets an external verifier be configured in.

::: example id=fig-may
title: The local verifier's one question, from Lab 7's solution
@file elixir solutions/07_authority.exs | def may?(%__MODULE__{secret: secret}, grant, request, _answer) do | request.now < grant.expires_at) +1
caption: Five conditions, all required: the grant carries the daemon's secret; its holder is not the thread asking; and its tools, its thread and its expiry cover the request. The lab tests attenuation as a property: over five hundred random cases, whatever a narrowed grant may answer, its parent may answer too.
:::

The plan includes a paragraph on what none of this can do, and it is worth repeating because it sets the limit of every later claim: a signature attests *custody*, not truth. The machinery can establish that a particular holder, under a particular grant, gave a particular answer at a particular time. It cannot establish that an agent reasoned honestly. What is being built is accountability, not verification.

### 30. An agent as an approver

A rule answers by matching a request's shape. Some requests need the proposal *read*: is this edit really equivalent, does this command do what it claims. The agent-approver plan lets a second thread, a **reviewer**, answer those.

The design is assembled entirely from parts already introduced, which is why `next.md` places it last among the scheduled steps.

- A reviewer is an ordinary thread, visible in the sidebar as a child of the thread it serves, with a normal transcript. This needs the *parent link* on a thread record, from the behaviour-shaped UI plan.
- Policy gains its fourth answer, *referable*. A referable request goes to the reviewer; anything else behaves as before. This needs the rules of [[s28]].
- The reviewer answers under a grant that is strictly weaker than the operator's, covering only categories the operator delegated, for a limited time. This needs the narrowing of [[s29]]. Shell commands and anything outside the working folder are not delegable in the first version.
- Its answer is a decision record naming the reviewer's thread and grant, with its reason stored. The operator can reverse it; the reversal is its own record, and reversals are what the rework measure counts.

Its safety rules restate ones the reader has met. A reviewer may never answer its own requests or those of a thread it descends from. A referred request that times out is not allowed; it becomes an ordinary ask. Where a rule would allow and the reviewer denies, the denial stands. And every answer given on the operator's behalf is countable on the dashboard, because "an automatic answer nobody can see is the failure mode to design against".

The plan first tied this work to the reviewer: no narrowing until a reviewer was wanted. That tie was dropped on 26 November 2026. The reviewer is not scheduled, and narrowing is kept for a different first use: each view of Stratta holding a grant cut to its job ([[s36]]).

### 31. One registry, three renderers

Today a new capability is added to Stratta three times: a button in the app, a key in the viewer, a verb in the command. Three plans, read together, replace that with one description from which the three are drawn.

**The specs.** Phase 0 of the code-mode plan gives every operation of [[s16]] a written spec: its arguments, its result, a one-line description and a flag for whether it only reads. A test fails if an operation has none. `stratta ops` prints them. This is small, and `next.md` schedules it early because two later steps consume it.

**The command language.** Today the words `approve 2a`, `use 3`, `send 2 fix the test` are understood only by the terminal client, which turns them into operations. The app-first plan moves the parser into the core and adds one operation, `command.run`, that takes a line of text. A line parses either to an operation or to a **view command**, something only a front end can carry out, such as showing the diff. Both front ends then accept the same words, a file of lines is a script (`source FILE`), and a key binding is a line with a key attached. With the specs in place the parser takes its argument checks and its help from them.

**The renderers.** A **registry**, in this plan's sense, is the operation specs together with the plugins a thread has. The behaviour-shaped UI plan draws three things from it: a command palette in the app, the same in the viewer, and the list of tools offered to a model. It adds a generated form for each operation from its argument schema, confirmation driven by the read-only flag, and a rule that an operation is offered only when it applies to this thread in this state. The plan sets its own test: adding one capability should add it to the app, the client and the model-facing tool list at once. If it only ever saves work in one of the three, it is not worth generating anything.

Two cautions from the plan keep this in proportion. Generated rendering is the fallback and not the aim: the screens used every day stay hand-made. And the smallest useful piece, a *parent thread id* on the thread record so that the sidebar can be a tree whose status rolls up from children, needs none of the rest and can be done first.

One temporary rule ties this section to [[s29]]. A script that can approve requests without a person looking adds to the confused-deputy risk. Until the local grant exists, `source` refuses lines that approve or deny. Afterwards it may accept them again, under a grant that says which requests it may answer.

### 32. Code mode: a model that writes code against the API

No model calls tools inside Stratta today. Each agent runs its own loop, and Stratta's own path has no model in it. The code-mode plan is about what happens when that changes: a model whose job is to manage threads, start several agents on a task, wait, compare their diffs and ship the best.

The obvious design gives that model one tool per operation. The plan argues for a different one. The model gets two tools: **search**, which finds operations and returns their signatures, and **execute**, which runs a script the model wrote against a small typed library generated from the operation specs. Loops, waits and filtering happen inside the script, and the model sees only what the script prints.

The reasons are about a model's **context window**, the bounded amount of text it can attend to at once. With one tool per operation, every operation's description is sent on every turn, a loop over five threads is five round trips through the model, and a three-thousand-line diff lands in the context. With search and execute, the up-front cost is two short descriptions however many operations exist, a loop is one script, and the diff is read by the script, which prints "12 files, tests pass".

The cost is that code written by a model has to be run somewhere safe. A **sandbox** is an environment in which untrusted code runs with almost no ability to affect anything outside it. The plan's has no network, no file access, and limits on time and memory. Its only way out is the generated library, and the way that is wired is the idea of [[s29]] in miniature. The sandboxed process does not open the control socket. The daemon starts it with a pipe, and each library call travels over the pipe as a request that the daemon checks against an allow list before running the operation. The script holds no handle the daemon did not give it. Which operations are on the list is set per orchestrator; shipping, pushing and deleting are off unless a person turns them on.

`next.md` schedules only Phase 0, the specs, which are useful by themselves. The rest waits for an orchestrating model to exist. Since 26 November the plan also sets a second design beside this one, in which the model writes a description of the work and not a program, and says why a script cannot simply run inside the daemon. [[S34]] takes up both.

### 33. Claims, and context as a recorded query

Two plans form an experiment about knowledge, and they are explicit that it may fail.

A **claim**, in the claim-graph plan, is a statement together with its grounds and what was ruled about it. The plan's observation is that a permission request is the one moment in a thread where a claim exists without being reconstructed: the agent must state what it intends before it may act, the events behind the statement are in the timeline, and a person or a rule rules on it. A *claim node* is written whenever a decision record is, in two layers. The structure comes from the daemon: the decision's id, the proposal, the evidence ids, the ruling, the files touched, and the parent claims, meaning earlier claims in the thread whose evidence this one's descends from. One sentence comes from the agent: what it takes itself to be claiming. That sentence is the only part a model writes, and it carries no links.

Claims come in two tiers. *Thread-local* claims are automatic, numerous and disposable. *Promoted* claims are moved one at a time, by a deliberate act, into a collection the operator keeps outside Stratta. The plan's first phase is a pilot that generates the structure alone from two or three real threads and asks whether it is of any interest. If not, the plan stops there.

The context-queries plan then asks what claims are *for*. It begins with a constraint stated in bold in the plan: Stratta does not own an agent's context window. Each agent assembles its own prompt. What Stratta controls is narrow: the text it sends, files it writes into the folder, and the **seed**, the material a thread is started or continued with.

The place the seed matters most is the **hand-off**, where a thread continues under a different agent in the same folder. Today the seed is a transcript: the last twenty user and assistant messages of the old thread, each cut to two thousand characters, sent once ahead of the new thread's first message. The plan proposes building the seed instead from the thread's claims and their grounds, as a query with a size budget, and *recording the query*: which claims went in and which were left out. That record is what makes a new kind of finding possible. When an agent gets something wrong after a hand-off, "the claim was not in the seed" and "the claim was in the seed and ignored" become distinguishable.

The whole track turns on one number, which `next.md` names: does a hand-off seeded with claims beat one seeded with the transcript *at equal size*? The plan asks for the result to be written down whichever way it goes.

### 34. Two graphs: what a thread leaves behind, and work across threads

In July 2026 the phrase "graph engineering" spread through writing about agents. The graphs plan was written on 26 November, after the operator read a guide to it and asked whether Stratta should adopt it or could be what it is built on. The plan's first move is to separate two things that the word covers.

The **record graph** is a graph of what was decided and on what grounds: decisions, the events behind them, claims, and the seeds built from claims. Stratta's plans already contain it, in [[s26]] and [[s33]], and the daemon writes all of it from what it already holds. The graphs plan adds nothing to it but the name.

The **work graph** is a graph of work: threads as points, with a line from one thread to another when the first one's outcome is the reason the second was started. This is the graph the phrase was coined for, and Stratta has part of it.

| A work graph needs | Stratta has today | Missing |
|---|---|---|
| a point: one bounded run of an agent | a thread | a stated outcome; a thread ends in prose |
| a place where control comes back | a named request, the end of a turn, shipping | nothing |
| a line | the `handoff_from` field that a hand-off writes | a parent link (step [[step:behaviour-ui]]) |
| a check that is not a model's opinion | the diff against the base commit | running the project's tests in the thread's folder |
| something to run it | nothing | see below |

The plan proposes four small things. A few fields on the thread record say how the last turn ended. An operation, `thread.check`, runs a command the operator has configured for the project and reports pass or fail. The parent link gains a note of what led to the child. From those three, a piece of work spread over several threads can be read back from the thread records alone.

For what runs a graph, the plan sets three candidates side by side, and the difference between them is what the graph *is*. In code mode ([[s32]]) it is a script that a model writes. As a flow under a durable run ([[s25]]) it is data: it can be shown before it runs, and it can only arrange actions that already exist. As a module written by hand it is ordinary Elixir against `Stratta.API`. The plan suggests the first graph be written the third way: one prompt given to two agents in two worktrees, a check run in each, and a report of which passed.

A reader may wonder why the script of [[s32]] runs in a separate program and not inside the daemon, which is good at running many things at once. The reason is that a process boundary on the BEAM is not a security boundary. [[S5]] said that processes share no memory and that one crashing does not disturb another. That protects against failure. It does not limit what code may do: code loaded into the node can open files, start programs, send to any process and replace modules. So code that a model wrote runs outside the node, or in an interpreter for another language that itself runs on the BEAM. A graph that is data avoids the question, because nothing in it is executed.

The plan also returns to the constraint of [[s33]], that Stratta does not own an agent's context window, and says what the record graph can do under each of three relations to an agent's context. In a *session*, today's arrangement, Stratta chooses what an agent starts from once, at the seed. Under a *request*, the experiment of the per-request plan, each message from the operator starts a fresh run of the agent, and Stratta chooses the starting text every time. In a *loop*, which no plan proposes yet, Stratta would call a model itself and choose before every call. The picture of several agents all reading and writing one shared graph cannot be built in the first, can be built at the edges of each run in the second, and can be built in full in the third. Who may write is a separate question in all three, and the rule that nothing a model wrote goes in unmarked does not change with them.

The plan reports what others have found and says that it is mixed. One company's account of three years of building with graphs says that the new thing is a point that is itself a whole agent, and also that its own research product went back from a fixed graph to a loop. A study of 180 arrangements found every arrangement of several agents worse than a single agent on tasks whose steps depend on each other. Three other Elixir libraries were read for the plan: Reactor, whose strength is undoing a half-finished procedure; Runic, used directly and not through Jido; and Journey, which keeps its state in a database server.

Nothing in the plan is scheduled except the spike of [[s25]]. It is labelled an exploration, and its first phase may be its last.

### 35. Files, shells, hosts and environments

The remaining plans are about where things are and how they are reached. Four ideas cover them.

**Detecting a conflicting write.** The app-first plan adds a file list and a Markdown editor for a thread's folder. The operator and the agent can now edit the same file. The plan's protection is that a write carries a hash of the content that was read; if the file has changed since, the write is refused and the current content is returned so both versions can be shown. Proceeding without a lock and checking at the last moment that nothing changed is **optimistic concurrency**. It suits this case because conflicts are rare and a refused save is cheap.

**A remote host is a daemon on that machine.** The daemon does everything that touches a thread's folder: it starts the agent, runs git, reads files, owns the shell. The app-first plan therefore rejects the idea of a local daemon driving a remote folder, which would need a second, remote form of each of those. Instead a remote host runs its own daemon, and the app needs only a way to reach that daemon's socket. SSH can forward a Unix socket from one machine to another, so the app keeps a list of hosts and one `ssh` process per host, using the operator's own SSH configuration and keys. This is the payoff of [[s16]]: once the app uses only operations and subscriptions, a daemon behind a forwarded socket looks the same as one in the same node. Names gain a prefix (`dev:2a`), and `ping` gains a protocol version so the app can refuse a daemon it cannot speak to.

**Two surfaces, two problems.** The remote-access plan separates the terminal client from the browser. The client can speak any transport, including ones that need no listening port on the daemon's machine and authenticate both ends. The browser cannot; it needs a listener, a certificate and a real login, which the plan assigns to the operator's own identity system and not to Stratta. What a remote caller may then *do* is a grant ([[s29]]): the point is that a connection from a phone can be allowed to approve and not to ship. The plan's first phase is documentation only, the two forwarding recipes that should already work and have never been tried, which is step [[step:choice-requests]].

**An environment is where a thread's files and processes live.** Today that is a worktree and a child process on the operator's machine. The environments plan names this as one implementation of a behaviour ([[s21]]) so that a thread could also run on a machine with instant file-system clones and checkpointable virtual machines. The plan avoids the word sandbox because the repository already uses it twice. It is gated by a spike that has nothing to do with Elixir: Stratta stores no credentials and uses each agent's own login, and a fresh environment has no login. If a login cannot reach an environment without passing through Stratta, the plan stops at the behaviour and the local implementation. Nothing else in `next.md` depends on it, which is why it is the one plan with no step.
@@part 7 | Reading next.md | the graph behind the list, and what each step asks you to know

### 36. The graph behind the list

`next.md` is a numbered list and nothing else. `state.md`, beside it, says what the numbers mean: each step comes after everything it needs "and nowhere later", and where two steps do not constrain each other, the operator's direction decides.

That direction changed on 26 November 2026, and the list was reordered the same day. The operator's own terminal is now the environment, and Stratta is a guest in it: an agent's own interface runs in one pane, and views that the operator or an agent opens sit beside it. The app is not dropped. It is taken apart into pages that each draw one thing, each shown in a pane and each bound to the daemon's state as the app is today ([[s13]]). What waits is the app as the place the operator works: its command bar, its file editor, its shell and its list of hosts. The concepts those need are still explained in this tutorial ([[s17]], [[s31]], [[s35]]), because the plans still exist.

The structure underneath is a **dependency graph**: the steps are points, and there is an arrow from one step to another when the second needs the first. Any list that never puts a step before something it needs is a **topological order** of the graph. There are usually many, and choosing among them is where preference comes in. Reading the list as a graph answers two questions the numbers alone do not: what can be done in parallel or out of order, and what is held up if a step slips. The reorder is an example: the arrows barely changed, and the order changed a great deal.

The handoff is two files: `next.md` holds the ordered steps, and `state.md` holds what is true now, including the direction and what is not scheduled. Since the same day each step also carries a kind, and each plan a section called *Why this exists*. A *need* is something observed in use or a fact in the code. An *experiment* is a question with a gate, built to be answered either way. An *exploration* is built because the operator wants to try an idea, with Stratta as the place to try it. The labels were added because the plans had outrun use: nineteen plans, and no reported day of work with a real agent. Two more plans were written later that day ([[s12]], [[s34]]); no step was added or moved for them. Eleven steps are newer than this account and are not in the diagram below, which draws the nineteen steps the rest of this part describes. Step [[step:propertydamage-trial]] tries a library for testing the daemon with generated sequences of commands. Step [[step:adopt-method]] puts in place the method the operator adopted for building Stratta, starting with a gate that runs on every push and a specification of the timeline. Steps [[step:open-tool-calls]], [[step:fold-raise]], [[step:second-reader]] and [[step:elixir-1-20]] ask the operator for decisions: what a thread shows for a tool call that never finished, whether the code that folds events may raise, how a second reader sees each change, and whether to require Elixir 1.20. Each links to an analysis written to be decided without the code. These six sit ahead of the rest by the operator's direction. Step [[step:adversarial]] asks whether one further plan, on testing Stratta's boundaries against an agent that misbehaves on purpose, enters the list, and step [[step:commitments-governance]] asks where the repository's design commitments are kept. The last three steps are about this tutorial and about one rule for the code. A label describes a step and does not rank it. After steps [[step:first-runs]] and [[step:pane-threads-0]] to [[step:telemetry]], a day of real work and a record of how long each request waited, the operator looks over the rest of the list again. The repository also now says that a threshold or a stopping rule written into a plan by an agent is a suggestion, and that such calls are the operator's to make. The plans also name the technologies they have in mind from that day on, Rex, terminal-browser, PixelGUI, QIP, Mjolnir, IdentiKey and artifact-dag among them, while Stratta's code stays neutral about all of them.

::: diagram id=fig-lanes file=lanes.svg
The nineteen steps, grouped as in section 4, with an arrow wherever `next.md` says one step needs another. Four arrows are left out to keep the picture readable: step [[step:pane-threads-1]] also needs step [[step:decision-records]], for the record a hooked request writes; step [[step:choice-requests]] needs step [[step:decision-records]]; and step [[step:composed-4]] needs steps [[step:telemetry]] and [[step:choice-requests]], for the data it draws and for the view that draws a choice.
:::

Four things stand out.

*Step [[step:decision-records]] is the root.* Decision records feed traces, policy, the local grant, claims, choices, and the pane-thread record. It is the one step whose delay moves almost everything.

*Step [[step:authority-1]] is the second hub.* The local grant needs the record (to put the grant's id in) and the reproduced hole (to prove it closed). The hole is now reproduced by two routes, a shell command and the app, because the app has no login. The grant is needed by any view that can answer a request, and step [[step:authority-2]] narrows it for each view.

*The pane-threads spike is first among the steps that build.* It is step [[step:pane-threads-0]]. It needs nothing from the other steps and it needs the operator's machine. It moved up because a pane thread is how an agent's own interface becomes a pane, and its finding is go or no-go for step [[step:pane-threads-1]].

*Step [[step:composed-1]] is where the app is taken apart.* It follows step [[step:code-mode-0]] only so that its new operations arrive with specs. After it, a step that adds something to look at adds it as a view: step [[step:composed-4]]'s timing view is the first new one and the test of the direction.

### 37. Step by step: what each step asks you to know

`next.md` names, under each step, the sections of this tutorial to read first, as links. This section used to hold a table of every step, which was a second copy of `next.md` and went stale whenever a step was added or moved. This part does not hold step numbers either. Where its source mentions a step it names it by a key, and the number printed on the page is looked up in `next.md` when the page is built (`source/steps.txt`, `scripts/steps.py`). So a step that is added or moved needs a rebuild and nothing else. `scripts/check_next.py` fails if a section `next.md` links to is gone, if a key no longer finds its step, or if the built pages are older than `next.md`.

A useful habit when a step begins: open its plan, find the section called *What happens today* or *What exists today*, and check each sentence against the code. Those sections were written from the code on one date, and they are the part of a plan most likely to have gone stale.

### 38. What is not scheduled, and what waits

Three kinds of phase are missing from the list above, and the plans use three words for why.

A **spike** is a short experiment whose product is a finding, written down, and not code that stays. The plans use spikes wherever a design depends on a fact nobody has checked: what a pane shows while a hook holds a request (step [[step:pane-threads-0]]), whether the Harness helper's pseudo-terminal carries a full-screen program without loss (the app-first plan's shell, now waiting), how a Rust verifier would be reached from the BEAM (authority Phase 3, where the three candidates are a NIF, a helper program over a pipe, and a port, as in [[s17]]), and how an agent's own login reaches a fresh environment (the environments plan).

A **gate** is a point where the result decides whether the rest happens at all. Policy Phase 0 is a gate on the Jido dependency. Claims Phase 0 is a gate on the whole claims and context track: if structure alone is of no interest, step [[step:context-queries]] does not happen. The comparison in step [[step:context-queries]] is a gate on starting threads from a query. Step [[step:first-runs]] holds a gate too: if a page of the app does not behave in a browser that draws in a terminal pane, the views plan is rewritten.

Every plan ends with a section called **Findings**, empty until its spike or first phase runs. A plan with an empty Findings section has not yet met reality, and its later phases should be read as intentions.

What is not on the list:

- *The app as an environment*: all six phases of the app-first plan, the app's half of slash commands, and the palette of the behaviour-shaped-UI plan, which is built on the app-first plan's command language. They return once the terminal direction has been used. Three of that plan's parts are not waiting: everything going through `Stratta.API` is what step [[step:code-mode-0]]'s protocol document assumes, its protocol version is built in step [[step:code-mode-0]], and its login is step [[step:authority-1]]'s grant.
- *Views* Phases 5 and 6, a view that is not a page and a view inside the viewer, until a reason is met in use.
- *Thread environments*, entirely, because nothing depends on it.
- *Code mode* Phases 1 to 4, which wait for an orchestrating model.
- *Ids and a log of events* Phases 2 to 4, the file of events, which wait on what step [[step:decision-records]] decides an evidence id should point at. Its Phase 1, the repair to ids, is built.
- *Graphs* Phases 1 to 3: a thread's outcome and a check, a first graph of two threads written by hand, and the choice of how graphs are run. They wait on the spike in step [[step:policy]] and on the operator.
- *Pane threads* Phases 2 and 4. Its Phase 3, policy, is superseded by step [[step:policy]].
- *Policy* Phase 4, the written assessment of Route B.
- *Traces* Phases 3 and 4, which wait on definitions of the remaining measures.
- *Behaviour-shaped UI* Phases 4 and 5, plugin cards and pending effects, which need policy as actions.
- *Claims* Phase 4 and *context queries* Phases 4 and 5, which wait on step [[step:context-queries]]'s result.
- *Authority* Phases 3 and 4, the external verifier and signed answers.
- *Choices* Phase 4, a space of steps declared in advance, which waits on step [[step:composed-4]].
- *The reviewer*, entirely, by the operator's decision on 26 November 2026: requests from coding agents have been appropriate in attended use, and it returns only if unattended work makes answering them a burden. [[s30]] still explains it.
- Remote access Phases 1 to 3.

### 39. The labs, and an order for reading the code

The seven labs are single files with their tests. Each is a miniature of a named part of Stratta.

| Lab | File | Sections | A miniature of |
|---|---|---|---|
| 1 | `01_thread_server.exs` | [[n6]] | `Stratta.ThreadServer`: one process owning requests, a debounced save |
| 2 | `02_supervision.exs` | [[n9]] | `ThreadSupervisor` and `ThreadRegistry`: start on demand, find by name |
| 3 | `03_timeline.exs` | [[n11]], [[n26]] | `Stratta.Timeline`: a fold over events, labels, evidence as ids |
| 4 | `04_pubsub.exs` | [[n13]], [[n14]] | topics on a Registry; the socket's coalescer |
| 5 | `05_socket.exs` | [[n15]] | `Stratta.Socket` and the client: frames, ids, pushes |
| 6 | `06_port.exs` | [[n17]], [[n18]] | an agent behind a port, holding its turn on a permission request |
| 7 | `07_authority.exs` | [[n21]], [[n28]], [[n29]] | planned: rules, a local grant with narrowing, an answer that names both |

To work a lab, run `elixir exercises/NN_name.exs`, replace each `raise("not implemented")` with a body, and run again until the tests pass. Compare with `solutions/` only after something passes. Both folders are generated from one master per lab in `source/labs/`, so their tests are identical.

::: example id=fig-transcript
title: The last lab's solution, run
@file text research/verify/labs-solutions.txt | $ elixir solutions/07_authority.exs | 13 tests, 0 failures
caption: From the transcript kept with the tutorial. Every solution passes, and every exercise file fails all of its tests until it is filled in; `scripts/run_labs.sh` checks both.
:::

Then read Stratta's own code, in an order that follows the request of [[s3]]. All paths are under `core/lib/stratta/` unless they say otherwise.

1. `application.ex`: the tree ([[s8]]). Thirty-six lines.
2. `store.ex`: the simplest GenServer in the project ([[s6]]).
3. `thread_server.ex`: read the client section, then `init/1`, then `handle_info` for events, then `broadcast/1`. Leave session management for a second pass.
4. `timeline.ex`: start at `apply_event/2` and read the clauses in order ([[s11]]).
5. `api.ex`: `call/2`, then `thread.approve` and the helper `approval_request/3` ([[s16]]).
6. `socket.ex`: the moduledoc states the protocol; then `init/1`, `serve/1` and `loop/1` ([[s15]]).
7. `tui/lib/stratta/tui/client.ex`, forty-seven lines, and `app.ex`: the other end of the socket ([[s20]]).
8. `gui/lib/stratta_web/live/app_live.ex`: `mount/3` and the `handle_info` clauses, to see the direct calls and subscriptions the app-first plan will move.

For more depth on a part: the Elixir course's lessons 6, 8 and 10; pages 8 and 9 of the memory-model wiki; the BEAM Book's chapters *Processes*, *Scheduling*, *IO, Ports and Networking* and *Interfacing Other Languages*; in Jido's guides, *Definitions and Runtime*, *OTP Concepts for Jido*, *Life of a Signal*, *Turns and Effects* and *Plugin Design*; in Harness's, *Overview*, *Interactive sessions*, *Wrap a coding agent in Jido V3* and the architecture reference. The Sources section gives the versions read.

### 40. What reading the references turned up

Writing this meant reading the plans against the code and the reference material they point to. Seven things came out of that which the plans did not say when they were written. Six are from reading. One was run, with one of Stratta's modules by itself, and has since been repaired; Stratta as a whole was not run.

**The plans say "skill" where Jido now says "plugin".** [[s23]] gives the correspondence. It matters when Phase 2 of the policy plan is built, because a search of Jido's version 3 guides for "skill" leads to an unrelated feature.

**"Actions in, new agent plus directives out" is the older shape.** The policy plan summarises a Jido agent that way. In version 3 the input is a signal and a route selects the action ([[s22]]). The substance the plan relies on, a pure function whose effects are returned as data, is unchanged.

**The Jido dependency is a beta, and it is not small.** The version read was `3.0.0-beta.3`, described by its own README as beta development whose APIs can change. Version 3 merges four former packages, among them the AI package, into one, so its required dependencies include an HTTP client and a language-model client that Stratta's policy use would never call. Harness's plugin guide pins one exact Jido revision. All of this bears on Phase 0, whose question is exactly "what comes with it".

**ThreadServer's `terminate/2` may not run when it matters.** The callback saves the timeline and closes the agent's session. OTP's documented rule is that a supervisor's shutdown runs `terminate/2` only in a process that traps exits, and ThreadServer does not ([[s7]]). Deleting a thread stops its process through the supervisor, and so does stopping the daemon. If the rule applies as documented, a deleted thread's agent session is not closed by this code path, and an event that arrived within the 400-millisecond save window before a shutdown is not written. Two tests would settle it: delete a thread with a live session and check that the session ends; stop the daemon just after an event and check that the item is on disk.

**The agent's hooks can now fail closed by themselves.** The pane-threads plan requires that a failing hook never approve, and achieves it by having `stratta hook` print no decision on any error. The hooks reference, as read for this tutorial, also describes a setting on a `PermissionRequest` hook that makes a failed hook deny. Whether "no decision" or "deny" is the right behaviour for a crashed hook is a design choice the spike in step [[step:pane-threads-0]] could record.

**Timeline item ids repeated after a restart.** [[S12]] has the run. A thread that continued after the daemon restarted gave a new item an id that an older item had, and a tool's result was then written into both. It was repaired on 27 November 2026: ids are counted per thread and the count is restored on load. A thread damaged before the repair keeps the damage.

**Jido has more than the plans drew on.** Flows, waits, durable runs, topology and a blackboard ([[s25]]) are in the version read, and the plans of 25 November mention none of them. The policy plan gives Route B as the way to get waiting and resuming. A durable run is documented as needing no AgentServer, which would put some of that within reach of Route A. Nobody has tried it.
