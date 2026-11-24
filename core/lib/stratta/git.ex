defmodule Stratta.Git do
  @moduledoc """
  Git and GitHub operations for threads: worktrees, diffs, commit, push, PR.

  Every call shells out to `git` (and `gh` for pull requests) in the thread's
  working directory, so it uses the user's existing configuration and auth.
  """

  @doc "Returns true when `path` is inside a git work tree."
  def repo?(path), do: match?({"true\n", 0}, git(path, ["rev-parse", "--is-inside-work-tree"]))

  def toplevel(path) do
    case git(path, ["rev-parse", "--show-toplevel"]) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, String.trim(out)}
    end
  end

  def current_branch(path) do
    case git(path, ["rev-parse", "--abbrev-ref", "HEAD"]) do
      {out, 0} -> String.trim(out)
      _ -> nil
    end
  end

  def head_sha(path) do
    case git(path, ["rev-parse", "HEAD"]) do
      {out, 0} -> String.trim(out)
      _ -> nil
    end
  end

  def has_commits?(path), do: not is_nil(head_sha(path))

  @doc """
  Creates `branch` from `base` in a new worktree under the project's
  `.stratta/worktrees/` directory. The directory ignores itself so it never
  shows up in the project's own status.
  """
  def create_worktree(project_path, branch, base) do
    root = Path.join(project_path, Application.get_env(:stratta, :worktree_dir, ".stratta/worktrees"))
    File.mkdir_p!(root)
    ignore = Path.join(Path.dirname(root), ".gitignore")
    unless File.exists?(ignore), do: File.write!(ignore, "*\n")

    dir = Path.join(root, branch |> String.replace(~r/[^A-Za-z0-9._-]+/, "-"))

    case git(project_path, ["worktree", "add", "-b", branch, dir, base]) do
      {_, 0} -> {:ok, dir}
      {out, _} -> {:error, String.trim(out)}
    end
  end

  def remove_worktree(project_path, dir) do
    git(project_path, ["worktree", "remove", "--force", dir])
    :ok
  end

  @doc """
  Unified diff of the working tree against `base` (a ref or sha), including
  untracked files. Returns parsed files, see `parse_diff/1`.
  """
  def diff(cwd, base \\ "HEAD"), do: cwd |> diff_text(base) |> parse_diff()

  @doc "The same diff as `diff/2`, as raw unified diff text."
  def diff_text(cwd, base \\ "HEAD") do
    base = if has_commits?(cwd), do: base, else: empty_tree(cwd)
    {tracked, _} = git(cwd, ["diff", "--no-color", "--no-ext-diff", base, "--"])

    {untracked_list, _} = git(cwd, ["ls-files", "--others", "--exclude-standard", "-z"])

    untracked =
      untracked_list
      |> String.split(<<0>>, trim: true)
      |> Enum.take(200)
      |> Enum.map(fn file ->
        {out, _} = git(cwd, ["diff", "--no-color", "--no-index", "--", "/dev/null", file])
        out
      end)

    IO.iodata_to_binary([tracked | untracked])
  end

  defp empty_tree(cwd) do
    {out, 0} = git(cwd, ["hash-object", "-t", "tree", "/dev/null"])
    String.trim(out)
  end

  @doc "Short status: list of {code, path}."
  def status(cwd) do
    {out, _} = git(cwd, ["status", "--porcelain=v1", "-uall"])

    out
    |> String.split("\n", trim: true)
    |> Enum.map(fn line -> {String.slice(line, 0, 2), String.slice(line, 3..-1//1)} end)
  end

  @doc "Number of commits on HEAD that are not on `base`."
  def ahead(cwd, base) do
    case git(cwd, ["rev-list", "--count", "#{base}..HEAD"]) do
      {out, 0} -> String.to_integer(String.trim(out))
      _ -> 0
    end
  end

  def commit(cwd, message, opts \\ []) do
    amend = if opts[:amend], do: ["--amend"], else: []

    with {_, 0} <- git(cwd, ["add", "-A"]),
         {out, 0} <- git(cwd, ["commit", "-m", message] ++ amend) do
      {:ok, String.trim(out)}
    else
      {out, _} -> {:error, String.trim(out)}
    end
  end

  def push(cwd, branch, opts \\ []) do
    force = if opts[:force], do: ["--force-with-lease"], else: []

    case git(cwd, ["push", "-u", "origin", branch] ++ force) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, String.trim(out)}
    end
  end

  def remote?(cwd), do: match?({out, 0} when out != "", git(cwd, ["remote"]))

  def gh_available?, do: not is_nil(System.find_executable("gh"))

  @doc "Opens a GitHub pull request with `gh`. Returns the PR URL."
  def create_pr(cwd, %{title: title, body: body, head: head} = attrs) do
    args =
      ["pr", "create", "--title", title, "--body", body, "--head", head] ++
        if(attrs[:base], do: ["--base", attrs.base], else: []) ++
        if(attrs[:draft], do: ["--draft"], else: [])

    case System.cmd("gh", args, cd: cwd, stderr_to_stdout: true) do
      {out, 0} -> {:ok, out |> String.split("\n", trim: true) |> List.last()}
      {out, _} -> {:error, String.trim(out)}
    end
  rescue
    e in ErlangError -> {:error, "gh failed: #{Exception.message(e)}"}
  end

  @doc """
  Parses unified diff text into
  `[%{path, status, additions, deletions, hunks: [%{header, lines: [{type, text}]}]}]`.
  """
  def parse_diff(text) do
    text
    |> String.split(~r/^diff --git /m, trim: true)
    |> Enum.map(&parse_file/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_file(chunk) do
    lines = String.split(chunk, "\n")
    path = file_path(lines)

    if path do
      {hunks, _} =
        Enum.reduce(lines, {[], false}, fn
          "@@" <> _ = header, {hunks, _} -> {[%{header: header, lines: []} | hunks], true}
          _line, {hunks, false} -> {hunks, false}
          "\\" <> _, acc -> acc
          "+" <> rest, {[h | t], true} -> {[add_line(h, :add, rest) | t], true}
          "-" <> rest, {[h | t], true} -> {[add_line(h, :del, rest) | t], true}
          " " <> rest, {[h | t], true} -> {[add_line(h, :ctx, rest) | t], true}
          _other, acc -> acc
        end)

      hunks = hunks |> Enum.reverse() |> Enum.map(&%{&1 | lines: Enum.reverse(&1.lines)})
      all = Enum.flat_map(hunks, & &1.lines)

      %{
        path: path,
        status: file_status(lines),
        additions: Enum.count(all, &(elem(&1, 0) == :add)),
        deletions: Enum.count(all, &(elem(&1, 0) == :del)),
        binary: Enum.any?(lines, &String.starts_with?(&1, "Binary files")),
        hunks: hunks
      }
    end
  end

  defp add_line(hunk, type, text), do: %{hunk | lines: [{type, text} | hunk.lines]}

  defp file_path(lines) do
    Enum.find_value(lines, fn
      "+++ b/" <> path -> path
      _ -> nil
    end) ||
      Enum.find_value(lines, fn
        "--- a/" <> path -> path
        _ -> nil
      end) ||
      case lines do
        [first | _] -> first |> String.split(" b/") |> List.last()
        _ -> nil
      end
  end

  defp file_status(lines) do
    cond do
      Enum.any?(lines, &String.starts_with?(&1, "new file")) -> :added
      Enum.any?(lines, &String.starts_with?(&1, "deleted file")) -> :deleted
      Enum.any?(lines, &String.starts_with?(&1, "rename from")) -> :renamed
      true -> :modified
    end
  end

  defp git(cwd, args) do
    System.cmd("git", args, cd: cwd, stderr_to_stdout: true, env: [{"GIT_TERMINAL_PROMPT", "0"}])
  rescue
    e -> {Exception.message(e), 1}
  end
end
