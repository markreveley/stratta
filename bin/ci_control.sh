#!/bin/sh
set -eu

usage() {
  echo "usage: bin/ci_control.sh seed" >&2
  echo "Writes one compiler warning, one badly formatted file and one failing test into each" >&2
  echo "of core/, gui/ and tui/. For a control branch only, never main: md/docs/ci.md." >&2
  exit 2
}

[ "${1:-}" = "seed" ] || usage

root=$(cd "$(dirname "$0")/.." && pwd)
branch=$(git -C "$root" rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]; then
  echo "refusing to seed faults on main; make a branch first: git checkout -b control/ci-faults" >&2
  exit 1
fi

for app in core gui tui; do
  name=$(printf '%s' "$app" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

  cat > "$root/$app/lib/ci_control_warning.ex" <<ELIXIR
defmodule CiControl.${name}Warning do
  def run(unused), do: :ok
end
ELIXIR

  cat > "$root/$app/lib/ci_control_format.ex" <<ELIXIR
defmodule CiControl.${name}Format do
  def run,    do:    :ok
end
ELIXIR

  cat > "$root/$app/test/ci_control_test.exs" <<ELIXIR
defmodule CiControl.${name}FailingTest do
  use ExUnit.Case

  test "seeded by the CI control" do
    flunk("seeded by the CI control")
  end
end
ELIXIR
done

echo "seeded 9 files on branch $branch; commit, push the branch, and read its run against md/docs/ci.md"
