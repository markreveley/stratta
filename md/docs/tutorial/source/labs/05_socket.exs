# Lab 5: a control socket                                (tutorial section 15)
#
# A miniature of Stratta.Socket and Stratta.TUI.Client: a Unix domain socket,
# frames with a 4-byte length prefix, one process per connection, requests
# matched to replies by id, and pushes that arrive in between.
#
# Stratta puts JSON in each frame. This lab puts an Erlang term in it, so the
# file needs no JSON library. The framing is the same.
#
# Run:  elixir exercises/05_socket.exs

ExUnit.start()

defmodule Lab.Socket do
  @opts [:binary, packet: 4, active: false]

  def encode(term), do: :erlang.term_to_binary(term)
  def decode(binary), do: :erlang.binary_to_term(binary, [:safe])

  # ---- server ---------------------------------------------------------------

  @doc """
  Listens on `path` and serves each connection in its own process.
  `handler.(op, args)` returns `{:reply, result}` or `{:push_then_reply, events, result}`.
  Returns the listening socket; close it to stop.
  """
  def start(path, handler) do
    File.rm(path)
    {:ok, listen} = :gen_tcp.listen(0, @opts ++ [ifaddr: {:local, path}])
    # >>>
    File.chmod!(path, 0o600)
    spawn_link(fn -> accept_loop(listen, handler) end)
    # ===
    # # 1. make the socket file readable and writable by its owner only
    # # 2. spawn_link a process that runs accept_loop(listen, handler)
    # _ = handler
    # <<<
    listen
  end

  # >>>
  defp accept_loop(listen, handler) do
    case :gen_tcp.accept(listen) do
      {:ok, sock} ->
        # The connection gets its own process, and the socket is handed to it.
        pid = spawn(fn -> receive(do: (:go -> serve(sock, handler))) end)
        :ok = :gen_tcp.controlling_process(sock, pid)
        send(pid, :go)
        accept_loop(listen, handler)

      {:error, _closed} ->
        :ok
    end
  end

  defp serve(sock, handler) do
    case :gen_tcp.recv(sock, 0) do
      {:ok, frame} ->
        %{id: id, op: op, args: args} = decode(frame)

        result =
          case handler.(op, args) do
            {:reply, result} ->
              result

            {:push_then_reply, events, result} ->
              for event <- events, do: :gen_tcp.send(sock, encode(%{event: event}))
              result
          end

        :gen_tcp.send(sock, encode(%{id: id, ok: true, result: result}))
        serve(sock, handler)

      {:error, _closed} ->
        :ok
    end
  end
  # ===
  # # accept_loop/2: accept a connection, give it its own process (remember
  # # :gen_tcp.controlling_process/2), and loop.
  # #
  # # serve/2: read one frame, decode it to %{id:, op:, args:}, call the
  # # handler, send any pushes as %{event: e}, then the reply as
  # # %{id: id, ok: true, result: r}, and loop until the client goes away.
  # <<<

  # ---- client ---------------------------------------------------------------

  def connect(path), do: :gen_tcp.connect({:local, path}, 0, @opts, 1_000)

  @doc """
  Sends a request and waits for the reply with the same id.
  Returns `{:ok, result, pushed}`: `pushed` is every event that arrived first.
  """
  def call(sock, op, args \\ %{}, timeout \\ 1_000) do
    id = System.unique_integer([:positive])
    :ok = :gen_tcp.send(sock, encode(%{id: id, op: op, args: args}))
    await(sock, id, timeout, [])
  end

  # >>>
  defp await(sock, id, timeout, pushed) do
    case :gen_tcp.recv(sock, 0, timeout) do
      {:ok, frame} ->
        case decode(frame) do
          %{id: ^id, ok: true, result: result} -> {:ok, result, Enum.reverse(pushed)}
          %{event: event} -> await(sock, id, timeout, [event | pushed])
          _someone_elses_reply -> await(sock, id, timeout, pushed)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
  # ===
  # defp await(_sock, _id, _timeout, _pushed), do: raise("not implemented")
  # <<<
end

defmodule Lab.SocketTest do
  use ExUnit.Case

  import Bitwise

  alias Lab.Socket

  setup do
    path = Path.join(System.tmp_dir!(), "lab-#{System.unique_integer([:positive])}.sock")

    handler = fn
      "ping", _args -> {:reply, %{pong: true}}
      "echo", args -> {:reply, args}
      "watch", args -> {:push_then_reply, [:tick, :tock], args}
    end

    listen = Socket.start(path, handler)

    on_exit(fn ->
      :gen_tcp.close(listen)
      File.rm(path)
    end)

    {:ok, path: path}
  end

  test "a request gets its reply", %{path: path} do
    {:ok, sock} = Socket.connect(path)
    assert Socket.call(sock, "ping") == {:ok, %{pong: true}, []}
    assert Socket.call(sock, "echo", %{text: "hi"}) == {:ok, %{text: "hi"}, []}
  end

  test "only the owner may open the socket file", %{path: path} do
    assert (File.stat!(path).mode &&& 0o777) == 0o600
  end

  test "pushes that arrive before the reply are not mistaken for it", %{path: path} do
    {:ok, sock} = Socket.connect(path)
    assert Socket.call(sock, "watch", %{thread: 2}) == {:ok, %{thread: 2}, [:tick, :tock]}
  end

  test "each connection is served on its own", %{path: path} do
    {:ok, one} = Socket.connect(path)
    {:ok, two} = Socket.connect(path)
    assert {:ok, %{n: 2}, []} = Socket.call(two, "echo", %{n: 2})
    assert {:ok, %{n: 1}, []} = Socket.call(one, "echo", %{n: 1})
  end

  test "a frame far larger than one read still arrives whole", %{path: path} do
    {:ok, sock} = Socket.connect(path)
    big = String.duplicate("x", 300_000)
    assert {:ok, %{text: ^big}, []} = Socket.call(sock, "echo", %{text: big})
  end

  test "on the wire, a frame is four bytes of length and then the payload", %{path: path} do
    # packet: :raw turns the framing off on this end, so the prefix is visible.
    {:ok, raw} = :gen_tcp.connect({:local, path}, 0, [:binary, packet: :raw, active: false], 1_000)
    payload = Socket.encode(%{id: 7, op: "ping", args: %{}})
    :ok = :gen_tcp.send(raw, <<byte_size(payload)::32, payload::binary>>)

    {:ok, <<length::32>>} = :gen_tcp.recv(raw, 4, 1_000)
    {:ok, reply} = :gen_tcp.recv(raw, length, 1_000)
    assert Socket.decode(reply) == %{id: 7, ok: true, result: %{pong: true}}
  end
end
