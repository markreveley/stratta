## Action
section: 22
match: action is a unit of work
In Jido, a module with a name, a schema for its parameters and a `run/2` function. An agent's [[g:route|routes]] say which action handles which signal type. The policy plan's Phase 2 expresses each rule as one.

## Adapter
section: 18
A module that tells Jido.Harness how to find and start one agent program and which optional features it has. It implements the `Jido.Harness.Adapter` [[g:behaviour|behaviour]]. `Stratta.DemoAdapter` is one.

## Agent
section: 1
In Stratta, an installed coding-agent program such as Claude Code or Codex. In Jido the word is wider: any long-lived thing that receives messages, holds state and decides what to do.

## Agent Client Protocol (ACP)
section: 18
match: agent client protocol
The protocol a coding agent speaks in protocol mode: [[g:json-rpc|JSON-RPC]] messages over its standard input and output, with the program that started it as the client.

## AgentServer
section: 22
Jido's live form of an agent: a process, built on OTP's `:gen_statem`, that holds an agent value and replaces it at each commit.

## Ambient authority
section: 29
A right that comes from where a program runs and who it runs as, not from anything it holds. Today the right to answer a request in Stratta is ambient: being able to open the socket.

## Append-only log
section: 26
A store to which records are added and in which none is ever changed. A correction is a new record that refers to the old one.

## Application
section: 8
In OTP, a unit that can be started and stopped as a whole: a set of modules and usually a function that starts a supervision tree. Any node that starts the `:stratta` application is a daemon.

## Attenuation
section: 29
Making a weaker capability from a stronger one. A grant that can be handed on only as something strictly weaker is what makes delegation expressible.

## Attribute
section: 27
match: attributes
A key and value attached to a [[g:span|span]], such as the thread id or who answered.

## Authority
section: 29
The right to have an action taken on your say. The authority plan makes the authority to answer a request something held and presented.

## Back-pressure
section: 14
A slow consumer limiting a fast producer. The socket's coalescer is a mild form: it never holds more than one pending state per thread for a client.

## Behaviour
section: 21
A list of functions a module may promise to provide. The promise is written `@behaviour Name`, and the compiler checks it. It lets code call a module chosen at run time against a fixed contract.

## Biscuit
section: 29
An open specification for capability tokens: verified with a public key, and attenuable offline by appending restrictions that cannot later be removed. The authority plan names it and says Stratta should not depend on it directly.

## Blackboard
section: 25
A named board of values that several parties read and change. In Jido a reader takes a snapshot with a revision, and a change is refused if the revision has moved, which is [[g:optimistic-concurrency|optimistic concurrency]].

## Call
section: 6
A message to a GenServer that waits for a reply, sent with `GenServer.call/3` and handled by `handle_call/3`.

## Callback
section: 21
One of the functions a [[g:behaviour|behaviour]] lists. `handle_call/3` is a callback of GenServer.

## Capability
section: 29
An unforgeable token that grants a specific right to whoever presents it. The plans call theirs a [[g:grant|grant]].

## Cast
section: 6
A message to a GenServer with no reply, sent with `GenServer.cast/2`. ThreadServer has none.

## Child
section: 8
match: children
A process started and watched by a [[g:supervisor|supervisor]].

## Child specification
section: 8
The description a supervisor is given for one child: a module, or a module with options, from which it learns how to start and restart the child.

## Claim
section: 33
In the claim-graph plan, a statement together with its grounds and what was ruled about it, written when a request is answered. Its structure comes from the daemon; one sentence comes from the agent.

## CloudEvents
section: 22
A public specification for describing events with a common envelope: an id, a source, a type and data. A Jido signal follows it.

## Coalescing
section: 14
Merging a burst of updates into the last one. The daemon holds the latest snapshot per thread for each client and sends it at most every 40 milliseconds.

## Coding agent
section: 1
A program that carries out a request in a folder of source code by running a language model in a loop of proposed actions and their results.

## Commit
section: 22
match: commits
In Jido, the moment in a turn when the runtime replaces the agent with the candidate. Before it, any failure leaves the agent unchanged. After it, nothing can be undone.

## Confused deputy
section: 29
A program used by one party with the authority of another. An agent-run shell command calling `stratta approve` makes the daemon one.

## Context window
section: 32
The bounded amount of text a language model can attend to at once. Code mode exists to keep operation descriptions and large results out of it.

## Control plane
section: 1
The part of a system that tells the operator what the working parts are doing and carries decisions back to them. Stratta is one for coding agents.

## Correlation
section: 15
Matching a reply to its request by an id both carry. It is needed on the control socket because pushes arrive between replies.

## Cursor
section: 12
A reader's position in a sequence. A reader that keeps one can stop and resume without missing or repeating anything.

## Daemon
section: 2
A long-running program with no user interface. Stratta's is `core/`: it owns the agents, the threads and their history.

## Debouncing
section: 6
Waiting for a quiet moment before doing expensive work, so that a burst of changes causes one write.

## Decision record
section: 26
Planned: one stored value per answered request, holding the request, the answer, who answered, two times, the evidence as ids, and the ground.

## Delta
section: 14
A message carrying only what changed. Stratta sends whole [[g:snapshot|snapshots]] instead.

## Dependency graph
section: 36
Steps as points, with an arrow from one to another when the second needs the first. `next.md` is one listing of such a graph.

## Directive
section: 22
In Jido, a struct that describes an effect, such as emitting a signal or stopping the agent, returned by an action and performed later by the runtime.

## Durable run
section: 25
A stored [[g:flow|flow]] run by `Jido.Durable`, saved at the boundary of each part so that it can wait and resume. Jido documents it as needing no [[g:agentserver|AgentServer]]. The graphs plan's spike tries one against `Stratta.API`.

## DynamicSupervisor
section: 9
A supervisor that starts with no children and is given them while running. `Stratta.ThreadSupervisor` is one, with a ThreadServer per open thread.

## Environment
section: 35
match: environment is where
Where a thread's files and processes live. Today a worktree and a child process on the operator's machine; the environments plan names that as one implementation of a behaviour.

## Escape sequence
section: 20
match: escape sequences
A run of bytes, beginning with the escape character, that instructs a terminal instead of being drawn.

## Event
section: 3
A small record that something happened: a type, a sequence number, a turn and a payload. Jido.Harness turns an agent's messages into events.

## Event log
section: 12
The full ordered list of events, kept as the record. Stratta does not keep one; it keeps the folded timeline. A plan of 26 November 2026 proposes one file of events for each thread.

## Fail closed
section: 28
match: fails closed
To fall back to the most cautious behaviour when something is wrong. A broken rule set answers nothing; a failing hook gives no decision.

## Fail open
section: 28
match: fails open
To fall back to permitting when something is wrong. The opposite of [[g:fail-closed|failing closed]].

## Findings
section: 38
The last section of every plan, empty until its spike or first phase has run and written down what it found.

## Flow
section: 25
match: flow is a graph
In Jido, a named graph of calls to [[g:action|actions]], written as data: each part names an action and says where its parameters come from. It can be checked before it runs and stored as JSON.

## Flow wait
section: 25
match: wait holds no process
A part of a [[g:flow|flow]] that suspends it until an event arrives or a time passes. The waiting flow saves its position and holds no process.

## Framing
section: 15
The rule by which a stream of bytes is divided into messages. Stratta's is a [[g:length-prefix|length prefix]].

## Front end
section: 2
match: front ends
A user interface that shows what the daemon holds and sends it commands. Stratta has two: the app in `gui/` and the `stratta` command in `tui/`.

## Gate
section: 38
A phase whose result decides whether the rest of a plan happens at all.

## GenServer
section: 6
OTP's standard pattern for a process that keeps state and handles one message at a time through callbacks you write.

## Grant
section: 29
The authority plan's capability: something an answer must present. First a local secret, later narrowed, signed, and verifiable across machines.

## Grapheme
section: 20
What a reader sees as one character, however many code points encode it. The composer plan keeps its cursor as a grapheme index.

## Hand-off
section: 33
Continuing a thread under a different agent in the same folder. Today the new thread is seeded with the tail of the old transcript.

## Headless thread
section: 18
A thread in which the daemon runs the agent in protocol mode and Stratta draws everything. Every thread is headless today.

## Hook
section: 19
A command an agent runs at a named moment in its own work, passing a description of the moment and, for some moments, reading a decision back.

## Idempotent
section: 9
Able to be done any number of times with the same result as once. `ensure_started/1` is.

## Jido
section: 22
A framework for building agents on the BEAM. The policy plan uses it for one job: answering permission requests.

## JSON-RPC
section: 18
A convention for requests and responses as JSON objects: a request has a method, parameters and an id; a response carries the same id.

## Length prefix
section: 15
Framing in which each message is preceded by its length. Stratta's is four bytes, handled by the runtime's `packet: 4` option.

## Let it crash
section: 7
The habit of handling only the failures code can do something useful about, and letting a supervisor replace a process that meets any other.

## Link
section: 7
A two-way connection between processes: if either exits abnormally, the other receives an exit signal.

## Mailbox
section: 5
The queue of messages other processes have sent to a process.

## Measure
section: 27
match: measures
One of five numbers the telemetry plan derives from spans: waiting time, rework, cost to a decision, automatic share and grounding.

## Monitor
section: 7
A one-way watch: the watcher receives a `:DOWN` message when the watched process exits, and carries on.

## NIF
section: 17
A native implemented function: foreign code loaded into the virtual machine itself. A crash in one can bring down the node, which is why agents are run behind [[g:port|ports]] instead.

## Node
section: 2
A running instance of the Erlang virtual machine. Processes in one node can call each other's functions and send each other messages directly.

## Notification
section: 18
A [[g:json-rpc|JSON-RPC]] request with no id, to which no response is expected. `session/update` is one.

## OpenTelemetry
section: 27
The vendor-neutral standard for producing traces and metrics, with agreed names for common attributes.

## Operation
section: 16
A named thing the daemon can be asked to do, with JSON-shaped arguments and result. `Stratta.API` has twenty-one, and the set is closed.

## Operation registry
section: 31
match: registry
In the behaviour-shaped UI plan, the operation specs together with the plugins a thread has: the one description from which the app, the terminal client and a model's tool list are drawn.

## Operator
section: 1
The person using Stratta.

## Optimistic concurrency
section: 35
Proceeding without a lock and checking at the last moment that nothing changed. The planned `file.write` carries a hash of what was read and is refused if the file has changed.

## OSC
section: 20
Operating system command: a family of escape sequences that carry data to the terminal program and draw nothing.

## OSC 8
section: 20
The escape sequence that marks a span of text as a link to a URL that is not itself displayed.

## OTLP
section: 27
OpenTelemetry's wire protocol for sending traces to a tool that stores or draws them.

## Pane thread
section: 19
Planned: a thread whose agent runs its own interface in a terminal pane and reports to the daemon through hooks.

## Permission request
section: 1
An agent's question, before an action, whether it may perform it. Its turn does not continue until somebody answers.

## Pid
section: 9
A process identifier. A restarted process has a new one, so Stratta finds processes by name.

## Plugin
section: 23
In Jido version 3, one module that adds a capability to an agent through optional callbacks, including a state field it owns. It is what the plans call a skill.

## Policy
section: 28
The set of rules that may answer a permission request without a person.

## Port
section: 17
The runtime's interface to a program that is not Erlang: the program's output and exit arrive as messages to the port's owner.

## Process
section: 5
A unit of execution scheduled by the virtual machine, with private memory and a mailbox.

## Process group
section: 17
An operating-system grouping that lets a signal be sent to a program and its descendants together.

## Projection
section: 11
A value computed by folding a list of events: one view of what happened. The timeline is the projection a chat screen needs.

## Provenance
section: 26
Being traceable to where it came from. A decision record has it because every field is stated by the agent's protocol or observed by the daemon.

## Provider
section: 1
The configuration that knows how to start one agent program.

## Pseudo-terminal
section: 20
A pair of connected endpoints from the operating system: one behaves like a terminal to the program attached to it, the other is read and written by a controlling program.

## Publish and subscribe
section: 13
The pattern in which interested processes subscribe to a named topic and a process with news broadcasts to it. PubSub for short.

## Pure core
section: 11
The arrangement in which state is computed by pure functions and a small process around them receives messages, saves and broadcasts.

## Pure function
section: 11
A function whose result depends only on its arguments and which changes nothing outside itself.

## Raw mode
section: 20
A terminal setting in which every key is delivered to the program as it is pressed.

## Record graph
section: 34
The graphs plan's name for what the decision, claims and context plans build together: decisions, the events behind them, claims, and the seeds made from claims. The daemon writes all of it.

## Reducer
section: 11
A function of the shape `(state, event) -> state`. `Timeline.apply_event/2` is one.

## Reduction
section: 5
match: reductions
The unit of the scheduler's budget, roughly one function call. A process that spends its budget is switched out.

## Registry
section: 9
A table from keys to processes that removes an entry when its process exits. `Stratta.ThreadRegistry` maps thread ids to ThreadServers; Phoenix.PubSub is built on one.

## Request name
section: 3
A slot number and a letter, such as `2a`, naming one permission request for good.

## Resolved path
section: 28
match: resolved
A path turned into the absolute path it actually refers to. "Inside the folder" must be judged after resolving.

## Restart value
section: 8
When a supervisor restarts a child: `:permanent` always, `:transient` only after an abnormal exit, `:temporary` never. ThreadServer is transient.

## Reviewer
section: 30
Planned: a second thread that answers referable requests under a narrowed grant, with its reasons recorded.

## Route
section: 22
match: routes
In a Jido agent, the mapping from a signal type to the action that handles it.

## Route A
section: 24
match: route a, policy only
ThreadServer keeps the Harness session; a plain Jido agent beside it holds only the rules.

## Route B
section: 24
match: route b, the plugin owns the thread
A Jido agent with the Harness plugin owns the session and becomes the thread; ThreadServer becomes its client.

## Rule
section: 28
A match on the shape of a request and an answer: allow, deny or ask. Rules are tried in order and the first match wins.

## Runic
section: 25
A separate Elixir library for dataflow graphs. Jido compiles a [[g:flow|flow]] to a Runic graph in order to run it. The version Jido requires is an alpha.

## Sandbox
section: 32
An environment in which untrusted code runs with almost no ability to affect anything outside it. In code mode, where a model's scripts run.

## Search and execute
section: 32
match: search
Code mode's two tools: one finds operations and returns their signatures, the other runs a script written against a library generated from the operation specs.

## Seed
section: 33
The material a thread is started or continued with. It is the one part of an agent's context that Stratta controls.

## Sequence number
section: 12
A number on each event that only increases within one session, so a reader can say where it has got to.

## Serialisation
section: 6
Turning concurrent requests into a sequence by sending them all through one process.

## Signal
section: 22
match: signal is the one kind of message
Jido's one kind of message: an envelope with a type, a source, an id and data, following [[g:cloudevents|CloudEvents]].

## Skill
section: 23
The plans' word for a Jido module with its own slice of state. In Jido version 3 that is a [[g:plugin|plugin]], and "skill" means a `SKILL.md` file of instructions.

## Slash command
section: 18
match: slash commands
A command an agent advertises, run by sending a prompt whose text begins with `/name`.

## Slot
section: 3
A small number a thread sits in, so that people can say `2` instead of an id.

## Snapshot
section: 3
The whole current state of a thread as one value. It is what the daemon broadcasts and what it saves.

## Socket
section: 2
A file-like endpoint through which two programs exchange bytes. Stratta's control socket is a [[g:unix-domain-socket|Unix domain socket]].

## Span
section: 27
One timed operation in a trace: a name, a start, an end, a parent and attributes.

## Spec
section: 16
Planned: the written description of one operation: arguments, result, one line, and whether it only reads.

## Spike
section: 38
A short experiment whose product is a finding written down, not code that stays.

## Steer
section: 1
To add a message to a turn that is still running.

## Strategy
section: 8
Which children a supervisor restarts when one dies. `:one_for_one` restarts only that one.

## Supervision tree
section: 8
The processes of a running system arranged by who supervises whom.

## Supervisor
section: 8
A process whose only job is to start other processes and restart them when they exit.

## Task
section: 10
A short-lived process that runs one function and exits.

## Task.Supervisor
section: 10
A supervisor for tasks, so that they belong to the tree and are cleaned up with it.

## Thread
section: 1
Stratta's unit: one conversation with one agent in one working folder, with everything that happened in it.

## Timeline
section: 3
The ordered list of things to show for a thread, folded from events by `Stratta.Timeline`.

## Tool
section: 1
match: tools
An action an agent can take during a turn: reading a file, editing one, running a command.

## Topic
section: 13
A name that processes subscribe to and broadcast on. Stratta has `thread:<id>`, `threads` and `current`.

## Topological order
section: 36
A listing of a dependency graph that never puts a step before something it needs.

## Topology
section: 25
In Jido, an agent's declaration of member agents that start when it starts, and of connections that route one member's output signals to another.

## Trace
section: 27
A tree of timed operations making up one piece of work. The telemetry plan exports a thread as one.

## Trapping exits
section: 7
Choosing to receive exit signals as messages. Only a process that traps exits has its `terminate/2` run when a supervisor shuts it down.

## Turn
section: 1
One loop of a coding agent, from a request to the point where it waits for the next. Jido uses the word for one signal handled by one agent.

## Unix domain socket
section: 15
A socket named by a path in the file system and reachable only from the same machine. The file's permissions decide who may connect.

## Via tuple
section: 9
A name of the form `{:via, Registry, {registry, key}}` that GenServer resolves through a registry at each call.

## View command
section: 31
In the planned command language, a line only a front end can carry out, such as showing the diff.

## Work graph
section: 34
The graphs plan's name for work arranged across threads: threads as points, with a line from one to another when the first one's outcome is the reason the second was started.

## Worktree
section: 1
A second checkout of the same git repository in another folder. A thread can have its own so that parallel threads do not edit each other's files.
