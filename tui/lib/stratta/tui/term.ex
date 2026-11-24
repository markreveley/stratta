defmodule Stratta.TUI.Term do
  @moduledoc """
  The terminal itself: raw mode, the alternate screen, size, and a reader
  process that forwards input to the process that entered.

  Pure Elixir on OTP 28's raw mode; no native code.
  """

  @reader :stratta_tui_reader

  @doc "True when both input and output are a terminal."
  def tty? do
    :prim_tty.isatty(:stdin) == true and :prim_tty.isatty(:stdout) == true
  catch
    _kind, _reason -> match?({:ok, _}, :io.columns())
  end

  def size do
    with {:ok, cols} <- :io.columns(), {:ok, rows} <- :io.rows() do
      {max(cols, 20), max(rows, 6)}
    else
      _ -> {80, 24}
    end
  end

  @doc "Switches to raw mode and the alternate screen. Input arrives as `{:keys, binary}` and `:eof`."
  def enter do
    saved = stty("-g")
    :shell.start_interactive({:noshell, :raw})
    # OTP's raw mode leaves the terminal's own signal and flow-control keys on,
    # so ctrl-c would kill us mid-frame and ctrl-s would freeze the screen.
    # Turn both off so they arrive as ordinary keys.
    if saved, do: stty("-isig -ixon")
    Process.put(:stratta_tui_stty, saved)
    start_reader(self())
    # alternate screen, save the window title, bracketed paste, clear
    IO.write("\e[?1049h\e[22;0t\e[?2004h\e[2J\e[H")
  end

  def leave do
    IO.write("\e[?2004l\e[0m\e[?25h\e[23;0t\e[?1049l")
    :shell.start_interactive({:noshell, :cooked})

    case Process.get(:stratta_tui_stty) do
      saved when is_binary(saved) -> stty(saved)
      _ -> nil
    end

    :ok
  end

  # Runs stty against our terminal. Child processes have no controlling
  # terminal of their own, so the device is found by name and passed as stdin.
  defp stty(args) do
    with path when is_binary(path) <- device(),
         {out, 0} <- System.cmd("sh", ["-c", "stty #{args} < #{path}"], stderr_to_stdout: true),
         out = String.trim(out),
         true <- out == "" or Regex.match?(~r/^[0-9A-Za-z:=]+$/, out) do
      out
    else
      _ -> nil
    end
  end

  defp device do
    case Process.get(:stratta_tui_device, :unknown) do
      :unknown ->
        path =
          with {name, 0} <- System.cmd("ps", ["-o", "tty=", "-p", System.pid()], stderr_to_stdout: true),
               name = String.trim(name),
               true <- Regex.match?(~r|^[A-Za-z0-9/]+$|, name),
               path = "/dev/" <> name,
               true <- File.exists?(path) do
            path
          else
            _ -> nil
          end

        Process.put(:stratta_tui_device, path)
        path

      path ->
        path
    end
  end

  # One reader for the life of the program: a second one would race it for input.
  defp start_reader(owner) do
    case Process.whereis(@reader) do
      nil -> Process.register(spawn(fn -> read_loop(owner) end), @reader)
      _pid -> true
    end
  end

  defp read_loop(owner) do
    case :io.get_chars(:standard_io, ~c"", 1024) do
      :eof ->
        send(owner, :eof)

      {:error, _reason} ->
        send(owner, :eof)

      data ->
        send(owner, {:keys, :unicode.characters_to_binary(data)})
        read_loop(owner)
    end
  end
end
