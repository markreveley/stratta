#!/usr/bin/env python3
"""Check every Stratta code excerpt in source/tutorial.md against a checkout of Stratta.

    python3 md/docs/tutorial/scripts/check_excerpts.py            # this repository
    python3 md/docs/tutorial/scripts/check_excerpts.py /path/to/stratta   # another checkout

An excerpt is a fenced block inside an example whose title is

    title: Stratta: path/inside/the/repository.ex

The block must appear in that file as a run of consecutive lines. Leading and trailing
whitespace on each line is ignored, and nothing else is. The result is printed and written to
research/verify/stratta-excerpts.txt with the checkout's commit, so the pages can say which
commit they describe. Exits non-zero if any excerpt is not found.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def norm(lines):
    return [l.strip() for l in lines]


def find(needle, hay):
    """Index of the first line of `needle` in `hay`, both lists of stripped lines, or -1."""
    needle = [l for l in needle]
    for i in range(len(hay) - len(needle) + 1):
        if hay[i:i + len(needle)] == needle:
            return i
    return -1


def excerpts():
    lines = open(os.path.join(ROOT, "source", "tutorial.md"), encoding="utf-8").read().split("\n")
    k = 0
    while k < len(lines):
        m = re.match(r"::: example id=(\S+)", lines[k])
        if not m:
            k += 1
            continue
        fig, path, block = m.group(1), None, None
        k += 1
        while lines[k].strip() != ":::":
            t = re.match(r"title: Stratta: (\S+)", lines[k])
            if t:
                path = t.group(1)
            if lines[k].startswith("```") and block is None:
                k += 1
                block = []
                while not lines[k].startswith("```"):
                    block.append(lines[k])
                    k += 1
            k += 1
        if path:
            yield fig, path, block or []
        k += 1


def main():
    if len(sys.argv) > 2:
        sys.exit(__doc__)
    repo = sys.argv[1] if len(sys.argv) == 2 else os.path.join(ROOT, "..", "..", "..")
    commit = subprocess.run(["git", "-C", repo, "log", "-1", "--format=%h %ad", "--date=short"],
                            capture_output=True, text=True).stdout.strip()
    out, bad = ["Stratta checkout: %s" % commit, ""], 0
    for fig, path, block in excerpts():
        try:
            hay = norm(open(os.path.join(repo, path), encoding="utf-8").read().split("\n"))
        except OSError:
            out.append("MISSING FILE  %-18s %s" % (fig, path))
            bad += 1
            continue
        needle = norm(block)
        while needle and not needle[0]:
            needle.pop(0)
        while needle and not needle[-1]:
            needle.pop()
        at = find(needle, hay)
        if at < 0:
            out.append("NOT FOUND     %-18s %s" % (fig, path))
            bad += 1
        else:
            out.append("ok            %-18s %s, lines %d to %d" % (fig, path, at + 1, at + len(needle)))
    out.append("")
    out.append("%d excerpt(s) checked, %d problem(s)" % (len(out) - 3, bad))
    text = "\n".join(out) + "\n"
    with open(os.path.join(ROOT, "research", "verify", "stratta-excerpts.txt"), "w", encoding="utf-8") as f:
        f.write(text)
    sys.stdout.write(text)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
