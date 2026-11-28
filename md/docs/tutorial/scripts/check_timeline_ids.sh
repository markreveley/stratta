#!/bin/sh
# Run Stratta's timeline module across two lifetimes of the virtual machine and keep the
# transcript under research/verify/.
#
#     sh md/docs/tutorial/scripts/check_timeline_ids.sh              # this repository
#     sh scripts/check_timeline_ids.sh <checkout> timeline-ids-before.txt   # another transcript name
#
# Only core/lib/stratta/timeline.ex is loaded, unchanged, beside a stand-in for the
# Jido.Harness.Event struct (scripts/timeline_ids/stub.exs). Stratta itself is not started,
# so this needs elixir and nothing else. The first run saves a thread's items; the second
# loads them and folds in one tool call. If item ids hold across a restart, the second run
# reports no repeated ids and the user's message is unchanged. Stratta repaired this on
# 27 November 2026; research/verify/timeline-ids-before.txt is the same check against the
# commit before the repair.

root=$(cd "$(dirname "$0")/.." && pwd)
stratta=$(cd "${1:-$root/../../..}" && pwd)
timeline="$stratta/core/lib/stratta/timeline.ex"
dir="$root/scripts/timeline_ids"
out="$root/research/verify/${2:-timeline-ids.txt}"
tmp=$(mktemp -d)
quiet() { grep -v -e '^warning' -e '^  ' -e '^$'; }

{
  echo "Stratta checkout: $(git -C "$stratta" log -1 --format='%h %ad' --date=short)"
  echo "\$ elixir --version"
  elixir --version 2>&1 | grep -v '^$'
  echo
  echo "\$ elixir -r stub.exs -r core/lib/stratta/timeline.ex run1.exs items.bin"
  elixir -r "$dir/stub.exs" -r "$timeline" "$dir/run1.exs" "$tmp/items.bin" 2>&1 | quiet
  echo
  echo "\$ elixir -r stub.exs -r core/lib/stratta/timeline.ex run2.exs items.bin"
  elixir -r "$dir/stub.exs" -r "$timeline" "$dir/run2.exs" "$tmp/items.bin" 2>&1 | quiet
} > "$out"

rm -rf "$tmp"
cat "$out"
grep -q '^repeated ids: \[\]' "$out" || { echo; echo "item ids repeat after a restart"; exit 1; }
