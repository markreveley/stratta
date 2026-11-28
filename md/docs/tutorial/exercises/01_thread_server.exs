# Lab 1: one process that owns a thread's state           (tutorial section 6)
#
# A miniature of Stratta.ThreadServer. One GenServer holds the permission
# requests of one thread. Callers never touch the state; they send a message
# and the server answers. Changes are saved after a short quiet period, the
# way ThreadServer debounces its writes to disk.
#
# Run:  elixir exercises/01_thread_server.exs

ExUnit.start()

defmodule Lab.ThreadServer do
  use GenServer

  # ---- client API: runs in the CALLER's process ----------------------------

  @doc "Options: `notify: pid` is told `{:saved, n}` on each save; `debounce: ms`."
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @doc "The agent raises a permission request. Returns its label: \"a\", then \"b\"."
  def request(pid, title), do: GenServer.call(pid, {:request, title})

  @doc "Answers a request. `:ok`, `{:error, :unknown}` or `{:error, {:already, decision}}`."
  def answer(pid, label, decision) when decision in [:approve, :deny],
    do: GenServer.call(pid, {:answer, label, decision})

  @doc "Labels of the requests still waiting, oldest first."
  def pending(pid), do: GenServer.call(pid, :pending)

  # ---- callbacks: run in the SERVER's process -------------------------------

  @impl true
  def init(opts) do
    state = %{
      requests: %{},
      seq: 0,
      notify: opts[:notify],
      debounce: opts[:debounce] || 20,
      timer: nil,
      saves: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(_message, _from, _state), do: raise("not implemented")

  @impl true
  def handle_info(:save, _state), do: raise("not implemented")
end

defmodule Lab.ThreadServerTest do
  use ExUnit.Case

  alias Lab.ThreadServer

  test "labels are handed out in order and never reused" do
    {:ok, pid} = ThreadServer.start_link()
    assert ThreadServer.request(pid, "edit README.md") == "a"
    assert ThreadServer.request(pid, "run mix test") == "b"
    assert ThreadServer.answer(pid, "a", :approve) == :ok
    assert ThreadServer.request(pid, "edit mix.exs") == "c"
  end

  test "an answer applies once, and only to a request that exists" do
    {:ok, pid} = ThreadServer.start_link()
    "a" = ThreadServer.request(pid, "edit README.md")
    assert ThreadServer.answer(pid, "a", :deny) == :ok
    assert ThreadServer.answer(pid, "a", :approve) == {:error, {:already, :deny}}
    assert ThreadServer.answer(pid, "z", :approve) == {:error, :unknown}
  end

  test "pending lists what is still waiting" do
    {:ok, pid} = ThreadServer.start_link()
    for title <- ["one", "two", "three"], do: ThreadServer.request(pid, title)
    :ok = ThreadServer.answer(pid, "b", :approve)
    assert ThreadServer.pending(pid) == ["a", "c"]
  end

  test "the state belongs to the server, whoever calls it" do
    {:ok, pid} = ThreadServer.start_link()
    other = Task.async(fn -> ThreadServer.request(pid, "from another process") end)
    assert Task.await(other) == "a"
    assert ThreadServer.pending(pid) == ["a"]
  end

  test "a burst of changes is saved once" do
    {:ok, pid} = ThreadServer.start_link(notify: self(), debounce: 30)
    for title <- ["one", "two", "three"], do: ThreadServer.request(pid, title)
    assert_receive {:saved, 1}, 500
    refute_receive {:saved, _}, 100

    :ok = ThreadServer.answer(pid, "a", :approve)
    assert_receive {:saved, 2}, 500
  end
end
