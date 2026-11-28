# Code comments

What this file is for: the code in `core/`, `gui/` and `tui/` carries no comments
([design commitment 5](design-commitments.md)), so anything a comment said is kept here,
where the operator can read it. It has two parts: the comments that are in the code now,
which must each be listed, and the text of the comments that were taken out.

## Comments in the code now

None.

Two things look like comments and are not counted as such:

- **Documentation attributes** (`@moduledoc`, `@doc`). The operator decided they are not
  comments. They are part of the program: the compiler stores them and `h` in a shell
  prints them. There are 87.
- **The first line of `core/priv/demo_agent/demo_acp.py`**, `#!/usr/bin/env python3`. It
  tells the system which program runs the file.

The commitment is applied to the three apps. The tutorial's exercises and the scripts
under `md/` are not covered by this file: an exercise's comments are its instructions to
the reader. That limit is the drafting agent's reading, not the operator's words.

## Recording a comment that has to stay

If a comment is ever absolutely necessary, say so to the operator when it is written and
add an entry under *Comments in the code now*: the file and the line it sits on, its
text, and why the code could not do without it. A comment in the code with no entry here
is a defect.

## Comments removed

Every comment was removed from the code as it stood at commit `986d034`: 169 comment
lines in 32 files. 157 were in Elixir files, 6 in the app's stylesheet, 3 in its script
and 3 in the demo agent. Line numbers below are the lines at that commit. "Above" names
the first line of code that followed the comment.

How it was checked, all run in the session that removed them:

- **Elixir.** The comments were found with Elixir's own parser, not by searching for
  `#`. Each file was parsed before and after, and the two syntax trees are equal once
  line numbers are set aside. The only lines the change touches are comment lines and
  blank lines.
- **The demo agent.** Python's parser gives the same tree before and after.
- **The script and the stylesheet.** Each removed line held a comment and nothing else.
  The script still parses.
- **The gate.** CI ran the format check and the tests on the commit that removed them.

Many comments were section headings, a line such as `# -- helpers ---` that divides a
file. They are gathered into one entry per file.

### `core/config/config.exs`

- **Lines 3 to 10, above `config :logger, :default_formatter, format: "$time $metadata[$level] $ …`.**

  ```
  Core needs no configuration to run. Optional keys:

    config :stratta,
      data_dir: "~/.stratta",             # projects, threads, transcripts, socket
      worktree_dir: ".stratta/worktrees", # per-thread worktrees, inside each project
      socket: true                        # serve the local control socket

  STRATTA_DATA_DIR overrides data_dir at runtime.
  ```

### `core/lib/stratta/api.ex`

- **Section headings, at lines 32, 36, 65, 97, 234.** daemon; projects & providers; threads; current thread; helpers.
- **Line 236, above `defp project_for(ref) do`.** A project reference is an id, a name, or a folder path (added on the fly).
- **Line 275, above `defp split_label(ref, label) when is_binary(ref) and label in [nil, "" …`.** "2a" is slot 2, request a. A label can also arrive on its own.
- **Lines 287 to 289, above `defp approval_request(thread, label, request_id) do`.** Which request an answer is for: a named one (by label or request id), or the only one waiting. A label that was already answered is refused, never redirected to a newer request.

### `core/lib/stratta/application.ex`

- **Lines 30 to 31, above `defp register_demo_provider do`.** Jido.Harness reads extra providers from its app env on every lookup, so the bundled demo agent can be registered here instead of in each host's config.

### `core/lib/stratta/providers.ex`

- **Lines 16 to 17, above `@stratta_options [:model, :approval_mode, :sandbox_mode, :reasoning_ef …`.** Options Stratta knows how to put in a SessionRequest. Each provider only receives the subset its ACP profile declares.

### `core/lib/stratta/socket.ex`

- **Section headings, at lines 48, 123.** listener; one connection.
- **Line 41, above `@max_path 103`.** sun_path is 104 bytes on macOS and 108 on Linux, including the terminator.
- **Lines 83 to 84, above `defp claim(path) do`.** A socket file left by a crashed daemon is removed; a live one means another daemon owns this data directory, and two would corrupt each other's state.

### `core/lib/stratta/store.ex`

- **Section headings, at lines 21, 28, 35, 52.** projects; threads; current thread per workspace; server.

### `core/lib/stratta/thread_server.ex`

- **Section headings, at lines 19, 65, 214, 438.** client; server; session management; helpers.
- **Line 178, above `@impl true`.** Events arrive from the follower task in order.
- **Lines 259 to 260, above `if request[:provider_session_id] do`.** Resume failed (the provider may have forgotten the conversation): retry once as a fresh conversation.
- **Line 359, above `{:error, _} -> with_how(Session.follow_up(state.session_id, text), :qu …`.** Raced with another turn starting: queue instead.
- **Lines 370 to 371, above `defp with_handoff_context(%{thread: %{"handoff_context" => ctx} = thre …`.** A handed-off thread sends the previous agent's transcript once, ahead of the first message, so the new provider starts with the context.
- **Lines 463 to 465, above `defp broadcast(state) do`.** Watchers of this thread hear about every change. The thread list only shows status, metadata and waiting requests, so it is told when one of those changes, not on every streamed token.

### `core/lib/stratta/threads.ex`

- **Section headings, at lines 6, 49, 74, 125, 282.** projects; threads; slots; current thread; git actions.
- **Line 69, above `{slotted, unslotted} = Enum.split_with(threads, & &1["slot"])`.** Slotted threads first, in slot order; list_threads/0 already put the rest newest first.
- **Lines 75 to 79, above `@max_slot 99`.** A slot is a small number a thread sits in, so people can say `2` instead of an id. A new thread takes the lowest free slot. Slots never shift on their own: one changes hands only when its thread is deleted, unslotted or moved.
- **Line 112, above `defp update_thread(id, fun) do`.** A running thread's process holds the authoritative copy of its metadata.
- **Lines 126 to 130, above `def current(workspace) do`.** Each workspace (a name; one shared "default" unless a client says otherwise) has a current thread: what commands act on when they name no thread, and what a dashboard shows. Changing it in one place is seen by every client watching that workspace.

### `core/lib/stratta/timeline.ex`

- **Section headings, at lines 167, 180, 229, 242, 268, 291, 312.** text streams; tools; plan / usage; approvals; turn lifecycle; provider events; helpers.
- **Line 51, above `defp number_items(items) do`.** Returns the items with every id distinct, and the highest item number in use.

### `core/mix.exs`

- **Lines 22 to 24, above `defp deps do`.** Set STRATTA_VENDOR_DEPS=/path/to/checkouts to build fully offline from local git checkouts (one directory per package). Otherwise deps come from Hex and GitHub as usual.

### `core/priv/demo_agent/demo_acp.py`

- **Line 22, at the end of `PENDING = {}`.** our outbound request id -> queue for the response
- **Line 29, at the end of `"turn": None,`.** (request_id, steer_queue)
- **Line 129, above `injected = []`.** Steering: anything the host injected mid-turn is acknowledged here.

### `core/test/socket_test.exs`

- **Line 2, above `use ExUnit.Case, async: false`.** Drives the daemon the way the terminal client does: over the control socket.
- **Line 31, above `defp recv_until(sock, fun) do`.** Reads frames until `fun` returns a truthy value for one of them.
- **Line 134, above `assert %{"ok" => true} = call(sock, 5, "thread.slot", %{"thread" => se …`.** Moving a thread into an occupied slot swaps the two.
- **Line 139, above `assert %{"ok" => true} = call(sock, 7, "thread.delete", %{"thread" => …`.** A deleted thread's slot is the next one handed out.
- **Line 143, above `assert %{"result" => %{"slot" => nil}} = call(sock, 9, "thread.slot", …`.** Unslotted threads keep working by id.
- **Line 179, above `request(sock, 6, "thread.send", %{"thread" => id, "text" => "edit two"})`.** The next request is b; a stale "a" must not answer it.
- **Line 196, above `%{"result" => %{"id" => second, "slot" => slot}} =`.** (The push for this change raced ahead of the reply above and was skipped by `call`.)
- **Line 205, above `assert %{"result" => %{"thread" => other}} = call(sock, 6, "current.ge …`.** Other workspaces are untouched, and deleting the current thread clears it.

### `core/test/thread_flow_test.exs`

- **Line 2, above `use ExUnit.Case, async: false`.** Drives a real Jido.Harness session against the bundled demo ACP agent.

### `core/test/timeline_test.exs`

- **Line 101, above `stored = tl.items |> Jason.encode!() |> Jason.decode!()`.** A reload stands in for a restart of the daemon: nothing but the stored items survives.
- **Line 112, above `assert Enum.take(reloaded.items, 3) == stored`.** The tool's result reaches the new item and no older one.

### `gui/config/config.exs`

- **Lines 10 to 11, above `config :logger, :default_formatter, format: "$time $metadata[$level] $ …`.** The core (`:stratta`) needs no configuration; see ../core/config/config.exs for its optional keys.

### `gui/lib/stratta_web/components.ex`

- **Section headings, at lines 38, 170, 193.** timeline; diff panel; helpers.

### `gui/lib/stratta_web/live/app_live.ex`

- **Section headings, at lines 57, 94, 161, 193, 234, 278.** pubsub; events: projects & threads; events: conversation; events: git; helpers; render.
- **Line 169, above `Task.start(fn -> ThreadServer.send_input(id, text, mode) end)`.** The first message may start a CLI, which can take a few seconds.
- **Line 254, above `defp project_threads(threads, project) do`.** A project's threads in slot order, then the unslotted ones (newest first, as stored).

### `gui/mix.exs`

- **Lines 22 to 24, above `defp deps do`.** Set STRATTA_VENDOR_DEPS=/path/to/checkouts to build fully offline from local git checkouts (one directory per package). Otherwise deps come from Hex and GitHub as usual.

### `gui/priv/static/assets/app.css`

- **Section headings, at lines 68, 74, 107, 114, 198, 213.** layout; sidebar; new thread; thread; panel; providers.

### `gui/priv/static/assets/app.js`

- **Line 1, above `(function () {`.** Stratta client: LiveView socket plus two small hooks. No build step.
- **Line 5, above `Hooks.ScrollBottom = {`.** Keep the timeline pinned to the bottom unless the user scrolled up.
- **Line 20, above `Hooks.Composer = {`.** Enter sends, Shift+Enter inserts a newline, Cmd/Ctrl+Enter steers.

### `tui/config/config.exs`

- **Line 4, above `config :stratta, data_dir: Path.join(System.tmp_dir!(), "stratta-tui-t …`.** The in-process daemon the tests talk to.

### `tui/lib/stratta/tui/cli.ex`

- **Section headings, at lines 131, 371, 410.** commands; views; plumbing.
- **Line 103, above `ErlangError -> 0`.** Output closed under us, as in `stratta ls | head -1`.
- **Line 373, above `defp attach(ref, opts) do`.** A view gets its own connection, so its subscription ends with it.
- **Line 443, above `defp with_thread(args, fun) do`.** Resolves the optional leading THREAD argument and passes on the rest.
- **Lines 490 to 491, above `defp send_target(_sock, [], _opts), do: {:usage, "Usage: stratta send …`.** Where a `send` goes. A thread is named with -t, or by a leading slot number or full id; otherwise every word is text for the current thread.
- **Line 521, above `defp tag(thread), do: to_string(thread["slot"] || thread["id"])`.** How people refer to a thread: its slot number, or its id if it has none.

### `tui/lib/stratta/tui/dashboard.ex`

- **Section headings, at lines 48, 84, 121, 258.** daemon frames; keys; rendering; status.
- **Line 39, above `defp focus(%{current: id} = st, id), do: st`.** Follow another thread: stop hearing about the old one, ask for the new one.
- **Line 111, above `defp select(%{current: id} = st, id), do: st`.** Changing the selection changes the workspace's current thread for everyone.
- **Lines 148 to 149, above `defp top(st, threads, waiting, w, limit) do`.** The thread list and the waiting requests: side by side when there is room, stacked when there is not.
- **Line 179, above `defp window(rows, selected, limit) do`.** At most `limit` rows, keeping the selected one in view.

### `tui/lib/stratta/tui/diff_view.ex`

- **Line 28, above `defp signature(snapshot) do`.** What must change in a thread before its diff can have changed.

### `tui/lib/stratta/tui/keys.ex`

- **Line 71, above `defp scan("\e[" <> rest, acc), do: scan(skip_csi(rest), acc)`.** An escape sequence we don't use: skip through its final byte.
- **Line 74, above `defp scan("\e" <> rest, acc), do: scan(drop_grapheme(rest), acc)`.** Alt+key: ignore both bytes.

### `tui/lib/stratta/tui/render.ex`

- **Section headings, at lines 31, 229, 249, 292.** timeline; unified diff text; text; frame.

### `tui/lib/stratta/tui/status.ex`

- **Section headings, at line 82.** escape sequences.

### `tui/lib/stratta/tui/term.ex`

- **Lines 30 to 32, above `if saved, do: stty("-isig -ixon")`.** OTP's raw mode leaves the terminal's own signal and flow-control keys on, so ctrl-c would kill us mid-frame and ctrl-s would freeze the screen. Turn both off so they arrive as ordinary keys.
- **Line 36, above `IO.write("\e[?1049h\e[22;0t\e[?2004h\e[2J\e[H")`.** alternate screen, save the window title, bracketed paste, clear
- **Lines 52 to 53, above `defp stty(args) do`.** Runs stty against our terminal. Child processes have no controlling terminal of their own, so the device is found by name and passed as stdin.
- **Line 87, above `defp start_reader(owner) do`.** One reader for the life of the program: a second one would race it for input.

### `tui/lib/stratta/tui/viewer.ex`

- **Section headings, at lines 33, 45, 121, 228.** daemon frames; keys; rendering; status.
- **Lines 142 to 143, above `defp lines(st, w) do`.** Wrapping a long thread on every repaint is wasted work while only the composer changes, so the wrapped lines are kept per snapshot and width.
- **Line 237, above `def leave(_st), do: [Status.clear(), Status.osc94(%{state: "idle"})]`.** Once detached, this terminal no longer speaks for the thread.

### `tui/mix.exs`

- **Lines 17 to 21, above `defp deps do`.** The client only needs Jason. The core is a test-only dependency, so the test suite can run a real daemon in-process and talk to it over the socket. Set STRATTA_VENDOR_DEPS=/path/to/checkouts to build fully offline from local git checkouts (one directory per package).

### `tui/test/cli_test.exs`

- **Lines 2 to 3, above `use ExUnit.Case, async: false`.** Runs the real commands and views against a real daemon (the core, started in this VM) driving the bundled demo agent.
- **Line 34, above `defp new_thread(dir, extra \\ []), do: json(["new", "-p", dir] ++ extra)`.** Starts a thread and returns it (its id, slot and so on).
- **Line 100, above `assert json(["status"])["thread"]["id"] == second["id"]`.** The newest thread is current, so commands without a thread act on it.
- **Line 110, above `assert {"Sent.", 0} = stratta(["send", "hello", "there"])`.** send: all words go to the current thread unless a slot or -t names another.
- **Line 144, above `st =`.** Type a message and press enter.
- **Line 172, above `{:cont, st} = Viewer.key({:char, "y"}, st, size)`.** "y" with an empty composer answers the approval instead of typing.
- **Line 201, above `{_, 0} = stratta(["send", to_string(first["slot"]), "edit", "something …`.** A command in "the other pane" raises a request in the first thread.
- **Line 218, above `{_, 0} = stratta(["use", to_string(first["slot"])])`.** `stratta use` elsewhere switches what the dashboard shows.
- **Line 226, above `slotted = Enum.filter(st.threads, & &1["slot"])`.** Moving the selection here changes the current thread for everyone.

### `tui/test/test_helper.exs`

- **Lines 1 to 2, above `System.put_env("STRATTA_SOCKET", Stratta.Socket.path())`.** The core application (a test-only dependency) is running in this VM as the daemon. Point the client at its socket.
