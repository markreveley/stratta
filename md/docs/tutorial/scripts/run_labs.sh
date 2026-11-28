#!/bin/sh
# Run every lab and keep the transcripts under research/verify/.
#
#     sh scripts/run_labs.sh
#
# solutions/  must pass with no failures and no compiler warnings.
# exercises/  must compile with no warnings and fail every test file, because
#             the stubs raise. A stub file that passed would mean it tests nothing.
#
# Exits non-zero if either condition is not met.

root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/research/verify"
mkdir -p "$out"
status=0

{
  echo "\$ elixir --version"
  elixir --version 2>&1 | grep -v '^$'
  echo
} > "$out/labs-solutions.txt"
cp "$out/labs-solutions.txt" "$out/labs-exercises.txt"

for f in "$root"/solutions/*.exs; do
  name=$(basename "$f")
  log=$(elixir "$f" 2>&1)
  # The seed and the timings differ on every run, so they stay out of the transcript.
  {
    echo "\$ elixir solutions/$name"
    echo "$log" | grep -v -e '^Randomized with seed' -e '^Finished in' -e '^$'
    echo
  } >> "$out/labs-solutions.txt"
  echo "$log" | grep -q ' 0 failures' || { echo "FAILED: solutions/$name"; status=1; }
  echo "$log" | grep -q 'warning:' && { echo "WARNING in solutions/$name"; status=1; }
done

for f in "$root"/exercises/*.exs; do
  name=$(basename "$f")
  log=$(elixir "$f" 2>&1)
  {
    echo "\$ elixir exercises/$name"
    echo "$log" | grep -e 'tests\{0,1\}, ' -e 'warning:' -e 'CompileError' -e 'SyntaxError'
    echo
  } >> "$out/labs-exercises.txt"
  echo "$log" | grep -q 'tests\{0,1\}, ' || { echo "DID NOT RUN: exercises/$name"; status=1; }
  echo "$log" | grep -q ' 0 failures' && { echo "STUB PASSES: exercises/$name"; status=1; }
  echo "$log" | grep -q 'warning:' && { echo "WARNING in exercises/$name"; status=1; }
done

[ "$status" = 0 ] && echo "run_labs.sh: ok" || echo "run_labs.sh: problems above"
exit $status
