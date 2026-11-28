#!/usr/bin/env python3
"""Write exercises/ and solutions/ from the lab masters in source/labs/.

    python3 scripts/make_labs.py

A master is one Elixir script holding both versions of each part the learner writes:

    # >>>
    ...the solution...
    # ===
    # ...the stub, commented out...
    # <<<

solutions/NN_name.exs keeps the solution and drops the stub. exercises/NN_name.exs drops the
solution and uncomments the stub. Everything outside the markers, the tests included, is the
same in both, so the two files cannot drift apart. Edit the masters, never the generated files.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source", "labs")


def split(name, text):
    solution, exercise, mode = [], [], None
    for n, line in enumerate(text.split("\n"), 1):
        mark = line.strip()
        if mark == "# >>>":
            if mode is not None:
                sys.exit("%s:%d: '# >>>' inside a marked region" % (name, n))
            mode = "solution"
        elif mark == "# ===":
            if mode != "solution":
                sys.exit("%s:%d: '# ===' outside a solution" % (name, n))
            mode = "stub"
        elif mark == "# <<<":
            if mode != "stub":
                sys.exit("%s:%d: '# <<<' without a stub" % (name, n))
            mode = None
        elif mode == "solution":
            solution.append(line)
        elif mode == "stub":
            m = re.match(r"^(\s*)# ?(.*)$", line)
            if not m:
                sys.exit("%s:%d: a stub line must be a comment" % (name, n))
            exercise.append((m.group(1) + m.group(2)).rstrip())
        else:
            solution.append(line)
            exercise.append(line)
    if mode is not None:
        sys.exit("%s: unclosed region" % name)
    return "\n".join(solution), "\n".join(exercise)


def main():
    names = sorted(f for f in os.listdir(SRC) if f.endswith(".exs"))
    for kind in ("solutions", "exercises"):
        os.makedirs(os.path.join(ROOT, kind), exist_ok=True)
    for name in names:
        with open(os.path.join(SRC, name), encoding="utf-8") as f:
            solution, exercise = split(name, f.read())
        solution = solution.replace("elixir exercises/", "elixir solutions/")
        for kind, text in (("solutions", solution), ("exercises", exercise)):
            with open(os.path.join(ROOT, kind, name), "w", encoding="utf-8") as f:
                f.write(text)
    print("make_labs.py: wrote %d exercises and %d solutions" % (len(names), len(names)))


if __name__ == "__main__":
    main()
