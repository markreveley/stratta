defmodule Stratta.TUI.Open do
  @moduledoc """
  `stratta open`: hands a thread to the user's own window layout.

  Stratta does not know how any particular terminal or multiplexer makes
  windows and splits. When `STRATTA_OPENER` is set, that shell command is run
  with the thread in its environment and is expected to start the views where
  it wants them:

    * `STRATTA_THREAD`: the thread id
    * `STRATTA_TITLE`: its title
    * `STRATTA_CWD`: its working directory (the worktree, if it has one)
    * `STRATTA_BIN`: this executable, so the opener can run
      `"$STRATTA_BIN" attach "$STRATTA_THREAD"` and
      `"$STRATTA_BIN" diff --watch "$STRATTA_THREAD"`

  Without an opener the caller attaches in the current terminal.
  """

  def run(thread) do
    case System.get_env("STRATTA_OPENER") do
      opener when opener in [nil, ""] ->
        :inline

      opener ->
        env = [
          {"STRATTA_THREAD", thread["id"]},
          {"STRATTA_TITLE", thread["title"] || ""},
          {"STRATTA_CWD", thread["cwd"] || ""},
          {"STRATTA_BIN", bin()}
        ]

        case System.cmd("sh", ["-c", opener], env: env, stderr_to_stdout: true) do
          {_out, 0} -> :ok
          {out, code} -> {:error, "The opener exited with status #{code}. #{String.trim(out)}"}
        end
    end
  end

  @doc "Path of the running `stratta` executable."
  def bin do
    case :escript.script_name() do
      [] -> "stratta"
      name -> name |> to_string() |> Path.expand()
    end
  catch
    _, _ -> "stratta"
  end
end
