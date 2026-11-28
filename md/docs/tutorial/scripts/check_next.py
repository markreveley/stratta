#!/usr/bin/env python3
"""Check next.md and this tutorial against each other.

    python3 md/docs/tutorial/scripts/check_next.py

1. Every link from next.md into source/tutorial.md names a section that exists, by its
   title and by the anchor GitHub gives its heading.
2. Every key in source/steps.txt finds exactly one step of next.md, and every
   [[step:key]] in the source has a key.
3. The built pages carry the step numbers next.md has now. If a step was added or moved
   since the last build, this says to rebuild.

Exits non-zero if any fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import steps  # noqa: E402

ROOT, REPO = steps.ROOT, steps.REPO


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

    nums = steps.numbers()
    used = set(re.findall(r"\[\[step:([a-z0-9-]+)\]\]", tutorial))
    for key in sorted(used - set(nums)):
        bad.append("[[step:%s]] has no line in source/steps.txt" % key)

    stamp = os.path.join(ROOT, "research", "build-steps.txt")
    built = open(stamp, encoding="utf-8").read() if os.path.exists(stamp) else ""
    now = "".join("%s\t%d\n" % (k, nums[k]) for k in sorted(nums))
    if built != now:
        bad.append("the pages were built with other step numbers than next.md has now: run make_diagrams.py and build.py")

    for b in bad:
        print("check_next.py: " + b)
    if bad:
        sys.exit(1)
    print("check_next.py: ok (%d links into the tutorial, %d keyed steps, %d used)" % (len(links), len(nums), len(used)))


if __name__ == "__main__":
    main()
