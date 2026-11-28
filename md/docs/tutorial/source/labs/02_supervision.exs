# Lab 2: one process per thread, found by name            (tutorial section 9)
#
# A miniature of Stratta.ThreadSupervisor + Stratta.ThreadRegistry. Workers
# are started on demand under a DynamicSupervisor and found through a
# Registry, so callers hold an id and never a pid.
#
# Run:  elixir exercises/02_supervision.exs

ExUnit.start()

defmodule Lab.Worker do
  # :transient = restart after a crash, stay down after a normal stop.
  use GenServer, restart: :transient

  def start_link(id), do: GenServer.start_link(__MODULE__, id, name: Lab.Threads.via(id))

  @impl true
  def init(id), do: {:ok, %{id: id, notes: []}}

  @impl true
  def handle_call({:note, text}, _from, state), do: {:reply, :ok, %{state | notes: [text | state.notes]}}
  def handle_call(:notes, _from, state), do: {:reply, Enum.reverse(state.notes), state}
end

defmodule Lab.Threads do
  @registry Lab.Registry
  @supervisor Lab.ThreadSupervisor

  @doc "The two children the lab's supervisor starts, as Stratta.Application does."
  def children do
    [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, name: @supervisor, strategy: :one_for_one}
    ]
  end

  def supervisor, do: @supervisor

  @doc "A name GenServer can resolve through the Registry."
  def via(id), do: {:via, Registry, {@registry, id}}

  # >>>
  @doc "Starts the worker for `id` unless it is running. Always `{:ok, pid}`."
  def ensure_started(id) do
    case DynamicSupervisor.start_child(@supervisor, {Lab.Worker, id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  @doc "The worker's pid, or nil. Never starts anything."
  def whereis(id) do
    case Registry.lookup(@registry, id) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  @doc ":running or :detached, without starting the worker."
  def status(id), do: if(whereis(id), do: :running, else: :detached)

  def note(id, text) do
    with {:ok, _pid} <- ensure_started(id), do: GenServer.call(via(id), {:note, text})
  end

  def notes(id) do
    with {:ok, _pid} <- ensure_started(id), do: GenServer.call(via(id), :notes)
  end
  # ===
  # @doc "Starts the worker for `id` unless it is running. Always `{:ok, pid}`."
  # def ensure_started(_id), do: raise("not implemented")
  #
  # @doc "The worker's pid, or nil. Never starts anything."
  # def whereis(_id), do: raise("not implemented")
  #
  # @doc ":running or :detached, without starting the worker."
  # def status(_id), do: raise("not implemented")
  #
  # def note(_id, _text), do: raise("not implemented")
  # def notes(_id), do: raise("not implemented")
  # <<<
end

defmodule Lab.ThreadsTest do
  use ExUnit.Case

  alias Lab.Threads

  setup do
    spec = %{
      id: :lab_root,
      type: :supervisor,
      start: {Supervisor, :start_link, [Threads.children(), [strategy: :one_for_one]]}
    }

    start_supervised!(spec)
    :ok
  end

  # Waits for a condition without sleeping blindly: at most three seconds.
  defp eventually(fun, tries \\ 600) do
    cond do
      fun.() -> :ok
      tries == 0 -> flunk("condition never became true")
      true ->
        receive do
        after
          5 -> eventually(fun, tries - 1)
        end
    end
  end

  test "ensure_started is idempotent" do
    {:ok, pid} = Threads.ensure_started("t1")
    assert {:ok, ^pid} = Threads.ensure_started("t1")
    assert Threads.whereis("t1") == pid
  end

  test "each id has its own process and its own state" do
    :ok = Threads.note("t1", "first")
    :ok = Threads.note("t2", "second")
    assert Threads.whereis("t1") != Threads.whereis("t2")
    assert Threads.notes("t1") == ["first"]
    assert Threads.notes("t2") == ["second"]
  end

  test "asking for status starts nothing" do
    assert Threads.status("t9") == :detached
    assert Threads.whereis("t9") == nil
    assert DynamicSupervisor.count_children(Threads.supervisor()).active == 0
  end

  test "a killed worker comes back under the same name, with empty state" do
    :ok = Threads.note("t1", "remember me")
    old = Threads.whereis("t1")
    ref = Process.monitor(old)
    Process.exit(old, :kill)
    assert_receive {:DOWN, ^ref, :process, ^old, :killed}, 2_000

    eventually(fn -> Threads.whereis("t1") not in [nil, old] end)
    # The supervisor restarts the process. It does not restore its memory.
    assert Threads.notes("t1") == []
  end

  test "a worker that stops normally stays down" do
    {:ok, pid} = Threads.ensure_started("t1")
    ref = Process.monitor(pid)
    :ok = GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000

    eventually(fn -> DynamicSupervisor.count_children(Threads.supervisor()).active == 0 end)
    assert Threads.status("t1") == :detached
  end
end
