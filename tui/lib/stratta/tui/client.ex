defmodule Stratta.TUI.Client do
  @moduledoc """
  Client for the Stratta daemon's control socket: JSON frames with a 4-byte
  length prefix over a Unix domain socket (see `Stratta.Socket` in core).
  """

  @doc "The daemon's socket: `STRATTA_SOCKET`, else `stratta.sock` in the data directory."
  def socket_path do
    System.get_env("STRATTA_SOCKET") ||
      Path.join(System.get_env("STRATTA_DATA_DIR") || Path.expand("~/.stratta"), "stratta.sock")
  end

  def connect(path \\ socket_path()) do
    :gen_tcp.connect({:local, path}, 0, [:binary, packet: 4, active: false], 2_000)
  end

  @doc "Sends a request and waits for its reply, skipping pushed events."
  def call(sock, op, args \\ %{}, timeout \\ 180_000) do
    await(sock, cast(sock, op, args), timeout)
  end

  @doc "Sends a request without waiting. Returns the request id its reply will carry."
  def cast(sock, op, args \\ %{}) do
    id = System.unique_integer([:positive])
    _ = :gen_tcp.send(sock, Jason.encode_to_iodata!(%{id: id, op: op, args: args}))
    id
  end

  def decode(data), do: Jason.decode!(data)

  defp await(sock, id, timeout) do
    case :gen_tcp.recv(sock, 0, timeout) do
      {:ok, data} ->
        case decode(data) do
          %{"id" => ^id, "ok" => true, "result" => result} -> {:ok, result}
          %{"id" => ^id, "error" => error} -> {:error, error}
          _other -> await(sock, id, timeout)
        end

      {:error, :timeout} ->
        {:error, "The daemon did not answer in time."}

      {:error, reason} ->
        {:error, "Lost the connection to the daemon (#{inspect(reason)})."}
    end
  end
end
