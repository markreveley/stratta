defmodule Stratta.Socket do
  @moduledoc """
  The daemon's local control socket.

  A Unix domain socket at `<data_dir>/stratta.sock` (override with
  `STRATTA_SOCKET`), readable and writable by the owner only. Nothing is
  opened on the network.

  ## Protocol

  Frames are JSON objects, each prefixed with its length as a 4-byte
  big-endian integer.

      → {"id": 1, "op": "thread.send", "args": {"thread": "tAb3", "text": "hi"}}
      ← {"id": 1, "ok": true, "result": {"how": "sent"}}
      ← {"id": 1, "ok": false, "error": "No thread matches \\"tAb3\\"."}

  Operations are those of `Stratta.API`, plus two that are tied to the
  connection:

    * `subscribe` with `{"thread": ref}` replies with the thread's snapshot,
      then pushes `{"event": "thread", "thread": id, "snapshot": {...}}`
      whenever it changes.
    * `subscribe` with `{"all": true}` replies with the thread list, then
      pushes `{"event": "threads", "threads": [...]}` whenever any thread's
      status or metadata changes.
    * `subscribe` with `{"current": workspace}` replies with that workspace's
      current thread id, then pushes
      `{"event": "current", "workspace": ..., "thread": id}` when it changes.
    * `unsubscribe` with `{"thread": id}` stops a thread's pushes.

  Pushes are coalesced: a burst of changes within 40 ms sends only the
  latest state, so a slow terminal never falls behind a fast agent.
  """
  use GenServer
  require Logger

  alias Stratta.{API, Store, Threads, ThreadServer}

  @flush_ms 40
  @max_path 103

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def path, do: System.get_env("STRATTA_SOCKET") || Path.join(Store.data_dir(), "stratta.sock")

  @impl true
  def init(:ok) do
    Process.flag(:trap_exit, true)
    path = path()
    File.mkdir_p!(Path.dirname(path))

    with :ok <- check_length(path),
         :ok <- claim(path),
         {:ok, listen} <- :gen_tcp.listen(0, [:binary, packet: 4, active: false, backlog: 64, ifaddr: {:local, path}]) do
      File.chmod(path, 0o600)
      me = self()
      acceptor = spawn_link(fn -> accept_loop(listen, me) end)
      {:ok, %{listen: listen, path: path, acceptor: acceptor}}
    else
      {:error, reason} ->
        Logger.error("Stratta control socket #{path} could not start: #{describe(reason)}")
        {:stop, {:socket, reason}}
    end
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.listen)
    File.rm(state.path)
    :ok
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{acceptor: pid} = state), do: {:stop, {:acceptor_down, reason}, state}
  def handle_info(_msg, state), do: {:noreply, state}

  defp check_length(path), do: if(byte_size(path) > @max_path, do: {:error, :path_too_long}, else: :ok)

  defp claim(path) do
    if File.exists?(path) do
      case :gen_tcp.connect({:local, path}, 0, [:binary, packet: 4, active: false], 500) do
        {:ok, sock} ->
          :gen_tcp.close(sock)
          {:error, :already_running}

        {:error, _} ->
          File.rm(path)
          :ok
      end
    else
      :ok
    end
  end

  defp describe(:already_running),
    do: "another Stratta daemon is already serving this data directory (stop it, or set STRATTA_DATA_DIR)"

  defp describe(:path_too_long), do: "the path is longer than #{@max_path} bytes (set STRATTA_SOCKET to a shorter one)"
  defp describe(reason), do: inspect(reason)

  defp accept_loop(listen, owner) do
    case :gen_tcp.accept(listen) do
      {:ok, sock} ->
        {:ok, pid} = Task.Supervisor.start_child(Stratta.TaskSupervisor, fn -> serve(sock) end)
        :gen_tcp.controlling_process(sock, pid)
        send(pid, :go)
        accept_loop(listen, owner)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        exit({:accept, reason})
    end
  end

  defp serve(sock) do
    receive do
      :go -> :ok
    after
      5_000 -> exit(:normal)
    end

    :inet.setopts(sock, active: :once)
    loop(%{sock: sock, topics: MapSet.new(), workspaces: MapSet.new(), pending: %{}, timer: nil})
  end

  defp loop(st) do
    receive do
      {:tcp, sock, data} ->
        st = handle_frame(data, st)
        :inet.setopts(sock, active: :once)
        loop(st)

      {:tcp_closed, _} ->
        :ok

      {:tcp_error, _, _} ->
        :ok

      {:reply, frame} ->
        push(st, frame)
        loop(st)

      {:thread, id, snapshot} ->
        loop(queue(st, {:thread, id}, snapshot))

      {:thread_status, _id, _status, _thread} ->
        loop(queue(st, :threads, true))

      :threads_changed ->
        loop(queue(st, :threads, true))

      {:current, workspace, thread_id} ->
        if MapSet.member?(st.workspaces, workspace) do
          push(st, %{"event" => "current", "workspace" => workspace, "thread" => thread_id})
        end

        loop(st)

      :flush ->
        for {key, value} <- st.pending do
          case key do
            {:thread, id} -> push(st, %{"event" => "thread", "thread" => id, "snapshot" => value})
            :threads -> push(st, %{"event" => "threads", "threads" => Threads.list_with_status()})
          end
        end

        loop(%{st | pending: %{}, timer: nil})

      _other ->
        loop(st)
    end
  end

  defp queue(st, key, value) do
    timer = st.timer || Process.send_after(self(), :flush, @flush_ms)
    %{st | pending: Map.put(st.pending, key, value), timer: timer}
  end

  defp handle_frame(data, st) do
    case Jason.decode(data) do
      {:ok, %{"op" => "subscribe"} = req} ->
        subscribe(req, st)

      {:ok, %{"op" => "unsubscribe", "args" => %{"thread" => id}} = req} ->
        topic = ThreadServer.topic(id)
        Phoenix.PubSub.unsubscribe(Stratta.PubSub, topic)
        push(st, reply(req["id"], {:ok, %{}}))
        %{st | topics: MapSet.delete(st.topics, topic), pending: Map.delete(st.pending, {:thread, id})}

      {:ok, %{"op" => op} = req} when is_binary(op) ->
        conn = self()

        Task.Supervisor.start_child(Stratta.TaskSupervisor, fn ->
          send(conn, {:reply, reply(req["id"], API.call(op, req["args"] || %{}))})
        end)

        st

      _ ->
        push(st, %{"ok" => false, "error" => "Malformed request."})
        st
    end
  end

  defp subscribe(%{"args" => %{"thread" => ref}} = req, st) do
    with {:ok, thread} <- Threads.resolve(ref),
         {:ok, snapshot} <- API.call("thread.get", %{"thread" => thread["id"]}) do
      st = join(st, ThreadServer.topic(thread["id"]))
      push(st, reply(req["id"], {:ok, %{"thread" => thread["id"], "snapshot" => snapshot}}))
      st
    else
      {:error, message} ->
        push(st, reply(req["id"], {:error, message}))
        st
    end
  end

  defp subscribe(%{"args" => %{"all" => true}} = req, st) do
    st = join(st, "threads")
    push(st, reply(req["id"], {:ok, %{"threads" => Threads.list_with_status()}}))
    st
  end

  defp subscribe(%{"args" => %{"current" => workspace}} = req, st) when is_binary(workspace) do
    st = join(st, "current")
    current = Threads.current(workspace)
    push(st, reply(req["id"], {:ok, %{"workspace" => workspace, "thread" => current && current["id"]}}))
    %{st | workspaces: MapSet.put(st.workspaces, workspace)}
  end

  defp subscribe(req, st) do
    push(st, reply(req["id"], {:error, "subscribe needs a thread, all: true, or current: workspace."}))
    st
  end

  defp join(st, topic) do
    if MapSet.member?(st.topics, topic) do
      st
    else
      Phoenix.PubSub.subscribe(Stratta.PubSub, topic)
      %{st | topics: MapSet.put(st.topics, topic)}
    end
  end

  defp reply(id, {:ok, result}), do: %{"id" => id, "ok" => true, "result" => result}
  defp reply(id, {:error, message}), do: %{"id" => id, "ok" => false, "error" => message}

  defp push(st, frame), do: :gen_tcp.send(st.sock, Jason.encode_to_iodata!(frame))
end
