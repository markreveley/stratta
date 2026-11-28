"""The steps of next.md, found by key and not by number.

source/steps.txt gives each step the tutorial mentions a key and the words its text
begins with in next.md. The number is looked up when the pages and the diagram are built,
so a step that is added or moved changes nothing here except a rebuild. If a step's
opening words change, the lookup fails and names the key.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.normpath(os.path.join(ROOT, "..", "..", ".."))


def texts():
    """{number: the step's text, on one line, without its label}."""
    s = open(os.path.join(REPO, "next.md"), encoding="utf-8").read()
    starts = [(m.start(), int(m.group(1))) for m in re.finditer(r"^(\d+)\. \*\*\(", s, re.M)]
    out = {}
    for k, (pos, n) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(s)
        t = re.sub(r"\s+", " ", s[pos:end]).strip()
        out[n] = re.sub(r"^\d+\. \*\*\([^)]*\)\*\* ", "", t)
    return out


def numbers():
    """{key: number}. Exits, naming the key, if a key matches no step or more than one."""
    steps, out, bad = texts(), {}, []
    for line in open(os.path.join(ROOT, "source", "steps.txt"), encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        key, begins = line.rstrip("\n").split("\t", 1)
        hits = [n for n, t in steps.items() if t.startswith(begins)]
        if len(hits) == 1:
            out[key] = hits[0]
        else:
            bad.append("%s: %d steps of next.md begin '%s'" % (key, len(hits), begins))
    if bad:
        sys.exit("steps.py: source/steps.txt and next.md disagree\n  " + "\n  ".join(bad))
    return out


def fill(text, nums=None):
    """Replace every [[step:key]] with that step's number."""
    nums = nums or numbers()

    def one(m):
        if m.group(1) not in nums:
            sys.exit("steps.py: [[step:%s]] has no line in source/steps.txt" % m.group(1))
        return str(nums[m.group(1)])
    return re.sub(r"\[\[step:([a-z0-9-]+)\]\]", one, text)
