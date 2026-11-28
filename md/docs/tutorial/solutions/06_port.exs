# Lab 6: an agent is another program            (tutorial sections 17 and 18)
#
# A port to an external program that speaks a line protocol on its standard
# input and output, the way an agent CLI speaks ACP. The "agent" is a dozen
# lines of shell. Half way through a turn it asks for permission and waits.
#
#   we send        prompt <text>         allow <id> | deny <id>     quit
#   it sends       update <text>         permission <id> <what>     done
#
# ACP's messages are JSON-RPC objects, one per line. These are three words.
# The shape of the conversation is the same: the request for permission
# travels from the agent to us, and the agent's turn is held until we answer.
#
# Run:  elixir solutions/06_port.exs

ExUnit.start()

defmodule Lab.Agent do
  @script ~S"""
  while read -r verb rest; do
    case "$verb" in
      prompt)
        echo "update thinking about: $rest"
        echo "permission 1 write hello.txt"
        read -r answer id
        if [ "$answer" = "allow" ]; then
          echo "update wrote hello.txt"
        else
          echo "update skipped the write"
        fi
        echo "done"
        ;;
      quit)
        exit 0
        ;;
    esac
  done
  """

  @doc "Writes the agent script into `dir` and starts it as an OS process behind a port."
  def open(dir) do
    path = Path.join(dir, "agent.sh")
    File.write!(path, @script)

    # spawn_executable passes the arguments as they are. No shell parses them.
    Port.open({:spawn_executable, System.find_executable("sh")}, [
      :binary,
      :exit_status,
      {:line, 4096},
      args: [path]
    ])
  end

  @doc "Writes one line to the program's standard input."
  def say(port, line) do
    Port.command(port, line <> "\n")
    :ok
  end

  @doc "The next thing the program did: `{:line, text}`, `{:exit, status}` or `:timeout`."
  def next(port, timeout \\ 2_000) do
    receive do
      {^port, {:data, {:eol, line}}} -> {:line, line}
      {^port, {:exit_status, status}} -> {:exit, status}
    after
      timeout -> :timeout
    end
  end

  @doc """
  Runs one turn. `decide.(what)` is called for each permission request and
  returns `:allow` or `:deny`. Returns the agent's updates, in order.
  """
  def turn(port, text, decide) do
    say(port, "prompt " <> text)
    collect(port, decide, [])
  end

  defp collect(port, decide, updates) do
    case next(port) do
      {:line, "update " <> update} ->
        collect(port, decide, [update | updates])

      {:line, "permission " <> rest} ->
        [id, what] = String.split(rest, " ", parts: 2)
        say(port, "#{decide.(what)} #{id}")
        collect(port, decide, updates)

      {:line, "done"} ->
        Enum.reverse(updates)
    end
  end
end

defmodule Lab.AgentTest do
  use ExUnit.Case

  alias Lab.Agent

  setup do
    dir = Path.join(System.tmp_dir!(), "lab-agent-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, port: Agent.open(dir)}
  end

  test "an approved turn", %{port: port} do
    assert Agent.turn(port, "add a greeting file", fn _what -> :allow end) ==
             ["thinking about: add a greeting file", "wrote hello.txt"]
  end

  test "a denied turn", %{port: port} do
    assert Agent.turn(port, "add a greeting file", fn _what -> :deny end) ==
             ["thinking about: add a greeting file", "skipped the write"]
  end

  test "the one who decides sees what is being asked", %{port: port} do
    test = self()

    Agent.turn(port, "anything", fn what ->
      send(test, {:asked, what})
      :allow
    end)

    assert_receive {:asked, "write hello.txt"}
  end

  test "the agent's turn is held until the request is answered", %{port: port} do
    :ok = Agent.say(port, "prompt add a greeting file")
    assert Agent.next(port) == {:line, "update thinking about: add a greeting file"}
    assert Agent.next(port) == {:line, "permission 1 write hello.txt"}

    # Nothing more happens, however long we wait, until we answer.
    assert Agent.next(port, 150) == :timeout

    :ok = Agent.say(port, "allow 1")
    assert Agent.next(port) == {:line, "update wrote hello.txt"}
    assert Agent.next(port) == {:line, "done"}
  end

  test "the program's exit is a message too", %{port: port} do
    :ok = Agent.say(port, "quit")
    assert Agent.next(port) == {:exit, 0}
  end
end
