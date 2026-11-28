# Lab 4: telling everyone who is watching               (tutorial section 13)
#
# Publish and subscribe in thirty lines on Registry, which is what
# Phoenix.PubSub is built on. Then a coalescer: the piece of Stratta.Socket
# that turns a burst of changes into one push carrying the latest state.
#
# Run:  elixir exercises/04_pubsub.exs

ExUnit.start()

defmodule Lab.PubSub do
  @name __MODULE__

  @doc "A Registry with duplicate keys: many processes may register one topic."
  def child_spec(_opts), do: Registry.child_spec(keys: :duplicate, name: @name)

  @doc "Subscribes the calling process to a topic."
  def subscribe(_topic), do: raise("not implemented")

  def unsubscribe(_topic), do: raise("not implemented")

  @doc "Sends `message` to every process subscribed to `topic`."
  def broadcast(_topic, _message), do: raise("not implemented")

  @doc "The pids subscribed to a topic."
  def subscribers(_topic), do: raise("not implemented")
end

defmodule Lab.Coalescer do
  @moduledoc """
  Receives `change(key, value)` as often as the source likes and forwards
  `{:flush, key, latest_value}` to `to` at most once per `flush_ms` per key.
  """
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  def change(pid, key, value), do: GenServer.cast(pid, {:change, key, value})

  @impl true
  def init(opts), do: {:ok, %{to: Keyword.fetch!(opts, :to), flush_ms: opts[:flush_ms] || 20, pending: %{}, timer: nil}}

  @impl true
  def handle_cast({:change, _key, _value}, _state), do: raise("not implemented")

  @impl true
  def handle_info(:flush, _state), do: raise("not implemented")
end

defmodule Lab.PubSubTest do
  use ExUnit.Case

  alias Lab.{Coalescer, PubSub}

  setup do
    start_supervised!(PubSub)
    :ok
  end

  # A process that subscribes, tells the test it is ready, and forwards what it hears.
  defp listener(topic, tag) do
    test = self()

    pid =
      spawn(fn ->
        PubSub.subscribe(topic)
        send(test, {:ready, tag})

        receive do
          message -> send(test, {tag, message})
        end
      end)

    assert_receive {:ready, ^tag}, 500
    pid
  end

  test "every subscriber of a topic hears a broadcast, and nobody else does" do
    listener("thread:1", :first)
    listener("thread:1", :second)
    listener("thread:2", :other)

    PubSub.broadcast("thread:1", {:thread, "1", :snapshot})

    assert_receive {:first, {:thread, "1", :snapshot}}, 500
    assert_receive {:second, {:thread, "1", :snapshot}}, 500
    refute_receive {:other, _}, 50
  end

  test "a subscriber that dies is forgotten without being told to unsubscribe" do
    pid = listener("threads", :gone)
    assert PubSub.subscribers("threads") == [pid]

    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500

    PubSub.broadcast("threads", :ignored)
    assert PubSub.subscribers("threads") == []
  end

  test "unsubscribe stops the messages" do
    :ok = PubSub.subscribe("current")
    PubSub.broadcast("current", :one)
    assert_receive :one, 500

    PubSub.unsubscribe("current")
    PubSub.broadcast("current", :two)
    refute_receive :two, 50
  end

  test "a burst of changes arrives as one message per key, carrying the latest value" do
    {:ok, coalescer} = Coalescer.start_link(to: self(), flush_ms: 30)

    for n <- 1..100, do: Coalescer.change(coalescer, {:thread, "1"}, n)
    Coalescer.change(coalescer, :threads, :changed)

    assert_receive {:flush, {:thread, "1"}, 100}, 500
    assert_receive {:flush, :threads, :changed}, 500
    refute_receive {:flush, _, _}, 100

    Coalescer.change(coalescer, {:thread, "1"}, 101)
    assert_receive {:flush, {:thread, "1"}, 101}, 500
  end
end
