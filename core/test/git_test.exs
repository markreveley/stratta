defmodule Stratta.GitTest do
  use ExUnit.Case, async: true

  alias Stratta.Git

  setup do
    dir = Path.join(System.tmp_dir!(), "stratta-git-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    run = fn args -> {_, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true) end
    run.(["init", "-q", "-b", "main"])
    run.(["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "init"])
    File.write!(Path.join(dir, "a.txt"), "one\ntwo\n")
    run.(["add", "."])
    run.(["-c", "user.email=a@b.c", "-c", "user.name=t", "commit", "-q", "-m", "a"])
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "diff includes modified and untracked files", %{dir: dir} do
    File.write!(Path.join(dir, "a.txt"), "one\nTWO\n")
    File.write!(Path.join(dir, "new.txt"), "hello\n")

    files = Git.diff(dir) |> Map.new(&{&1.path, &1})
    assert %{status: :modified, additions: 1, deletions: 1} = files["a.txt"]
    assert %{status: :added, additions: 1, deletions: 0} = files["new.txt"]
  end

  test "worktrees are created on a new branch and ignored by the project", %{dir: dir} do
    {:ok, wt} = Git.create_worktree(dir, "stratta/test-1", "HEAD")
    assert Git.current_branch(wt) == "stratta/test-1"
    assert Git.status(dir) == []
    Git.remove_worktree(dir, wt)
  end

  test "commit and push a worktree branch to a remote", %{dir: dir} do
    bare = dir <> "-remote.git"
    {_, 0} = System.cmd("git", ["init", "-q", "--bare", bare])
    {_, 0} = System.cmd("git", ["remote", "add", "origin", bare], cd: dir)
    on_exit(fn -> File.rm_rf!(bare) end)

    {:ok, wt} = Git.create_worktree(dir, "stratta/push-1", "HEAD")
    File.write!(Path.join(wt, "b.txt"), "b\n")

    System.put_env([
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "a@b.c"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "a@b.c"}
    ])

    assert {:ok, _} = Git.commit(wt, "add b")
    assert Git.ahead(wt, "main") == 1
    assert Git.remote?(wt)
    assert {:ok, _} = Git.push(wt, "stratta/push-1")
    assert {_, 0} = System.cmd("git", ["rev-parse", "stratta/push-1"], cd: bare)
  end
end
