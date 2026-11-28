#!/bin/sh
# Builds what the spike needs and runs it. No Mix and no Hex: it works on Elixir 1.14.
#
#   run.sh CHECKOUTS [props|census|confirm|mutants]
#
# CHECKOUTS holds git checkouts named stream_data and jason. Run from the repo's root.
set -e
here=$(cd "$(dirname "$0")" && pwd)
deps=$1; what=${2:-props}
out=${SPIKE_OUT:-/tmp/stratta-spike}; mkdir -p "$out/sd" "$out/jason" "$out/stub" "$out/tl"
[ -f "$out/sd/Elixir.StreamData.beam" ] || elixirc -o "$out/sd" $(find "$deps/stream_data/lib" -name '*.ex') >/dev/null 2>&1
[ -f "$out/jason/Elixir.Jason.beam" ] || elixirc -o "$out/jason" $(find "$deps/jason/lib" -name '*.ex') >/dev/null 2>&1
elixirc -o "$out/stub" "$here/event_stub.ex"
PA="-pa $out/sd -pa $out/jason -pa $out/stub"
elixirc $PA -o "$out/tl" core/lib/stratta/timeline.ex

case $what in
  props)   RUNS=${RUNS:-1000} elixir $PA -pa "$out/tl" -r "$here/helper.exs" "$here/timeline_props_test.exs" ;;
  census)  N=${N:-30000} elixir $PA -pa "$out/tl" "$here/crash_census.exs" ;;
  confirm) elixir $PA -pa "$out/tl" -r "$here/helper.exs" "$here/confirm.exs" ;;
  mutants)
    python3 "$here/mutate.py" core/lib/stratta/timeline.ex "$out/mutants"
    for d in "$out"/mutants/m*; do
      id=$(basename "$d"); mkdir -p "$d/ebin"
      if ! elixirc $PA -o "$d/ebin" "$d/timeline.ex" >"$d/compile.log" 2>&1; then echo "$id compile_error - -"; continue; fi
      if elixir $PA -pa "$d/ebin" -r "$here/helper.exs" core/test/timeline_test.exs >"$d/existing.log" 2>&1; then e=survived; else e=killed; fi
      if GREEN_ONLY=1 RUNS=200 elixir $PA -pa "$d/ebin" -r "$here/helper.exs" "$here/timeline_props_test.exs" >"$d/props.log" 2>&1; then p=survived; else p=killed; fi
      echo "$id ok $e $p"
    done ;;
esac
