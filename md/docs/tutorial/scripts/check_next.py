#!/usr/bin/env python3
"""Check next.md and this tutorial against each other.

    python3 md/docs/tutorial/scripts/check_next.py

1. Every link from next.md into source/tutorial.md names a section that exists, by its
   title and by the anchor GitHub gives its heading.
2. Every step that Part 7 cites by number still begins, in next.md, the way
   source/steps.txt says it does. When a step is added or moved, this fails and says
   which numbers to correct in Part 7, the diagram and steps.txt.

Exits non-zero if either fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.normpath(os.path.join(ROOT, "..", "..", ".."))


def slug(heading):
    h = re.sub(r"[^a-z0-9 \-_]", "", heading.lower())
    return h.replace(" ", "-")


def main():
    tutorial = open(os.path.join(ROOT, "source", "tutorial.md"), encoding="utf-8").read()
    nxt = open(os.path.join(REPO, "next.md"), encoding="utf-8").read()
    sections = {}
    for m in re.finditer(r"^### (\d+\. (.+))$", tutorial, re.M):
        sections[slug(m.group(1))] = m.group(2).strip()
    bad = []

    links = re.findall(r"\[([^\]]+)\]\(md/docs/tutorial/source/tutorial\.md#([^)]+)\)", nxt)
    for text, anchor in links:
        if anchor not in sections:
            bad.append("next.md links to a section that is not there: #%s (%s)" % (anchor, text))
        elif sections[anchor] != text:
            bad.append("next.md calls #%s '%s'; the tutorial calls it '%s'" % (anchor, text, sections[anchor]))

    steps = {int(m.group(1)): m.group(2) for m in re.finditer(r"^(\d+)\. \*\*\([^)]*\)\*\* (.*)$", nxt, re.M)}
    cited = 0
    for line in open(os.path.join(ROOT, "source", "steps.txt"), encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        n, begins = line.rstrip("\n").split("\t", 1)
        cited += 1
        if not steps.get(int(n), "").startswith(begins):
            bad.append("step %s of next.md no longer begins '%s': Part 7's numbers need a pass" % (n, begins))

    for b in bad:
        print("check_next.py: " + b)
    if bad:
        sys.exit(1)
    print("check_next.py: ok (%d links into the tutorial, %d cited steps)" % (len(links), cited))


if __name__ == "__main__":
    main()
