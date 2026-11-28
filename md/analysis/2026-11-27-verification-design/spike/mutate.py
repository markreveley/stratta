#!/usr/bin/env python3
"""Writes one-change mutants of an Elixir source file. Usage: mutate.py SRC OUTDIR"""
import re, sys, os, json

src, out = sys.argv[1], sys.argv[2]
lines = open(src).read().split("\n")

OPS = [
    ("eq->neq", r" == ", " != "), ("neq->eq", r" != ", " == "),
    ("plus1->plus0", r" \+ 1\b", " + 0"), ("minus1->minus0", r" - 1\b", " - 0"),
    ("and->or", r" and ", " or "), ("or->and", r" or ", " and "),
    ("||->&&", r" \|\| ", " && "), ("&&->||", r" && ", " || "),
    ("max->min", r"\bmax\(", "min("),
    ("any->all", r"Enum\.any\?", "Enum.all?"),
    ("lt->lte", r" < ", " <= "), ("gt->gte", r" > ", " >= "),
    ("drop-not", r"\bnot ", ""),
    ("pending->expired", r'"pending"', '"expired"'),
    ("expired->pending", r'"expired"', '"pending"'),
    ("approved->denied", r'"approved"', '"denied"'),
    ("denied->approved", r'"denied"', '"approved"'),
    ("interrupted->completed", r'"interrupted"', '"completed"'),
    ("in_progress->done", r'"in_progress"', '"done"'),
    ("append->prepend", r"tl\.items \+\+ \[item\]", "[item] ++ tl.items"),
    ("put_new->put", r"Map\.put_new\(", "Map.put("),
    ("concat-drop-old", r"fn t -> t <> text end", "fn _t -> text end"),
    ("concat-drop-old-o", r"fn o -> o <> text end", "fn _o -> text end"),
    ("true->false", r"\btrue\b", "false"),
    ("kind-swap", r'"assistant"', '"thinking"'),
    ("update_at-last->first", r"List\.update_at\(tl\.items, -1,", "List.update_at(tl.items, 0,"),
    ("delete->put", r"MapSet\.delete\(", "MapSet.put("),
    ("member-negate", r"not MapSet\.member\?", "MapSet.member?"),
    ("seq+1->seq", r"seq \+ 1", "seq"),
    ("rem->div", r"\brem\(", "div("),
]

in_doc, mutants = False, []
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith(('@moduledoc """', '@doc """')):
        in_doc = True
        continue
    if in_doc:
        if stripped == '"""':
            in_doc = False
        continue
    if stripped.startswith(("#", "@doc", "@type", "alias", "defmodule")) or not stripped:
        continue
    code = line.split(" # ")[0]
    for name, pat, rep in OPS:
        for m in re.finditer(pat, code):
            new = code[:m.start()] + rep + code[m.end():]
            mutants.append((name, i, new))
    # a pipeline step removed
    if stripped.startswith("|> ") and not lines[i - 1].strip().startswith(("%{", "{")):
        mutants.append(("drop-pipe-step", i, None))

os.makedirs(out, exist_ok=True)
index = []
for n, (name, i, new) in enumerate(mutants):
    body = lines[:i] + ([] if new is None else [new]) + lines[i + 1:]
    d = os.path.join(out, f"m{n:03d}")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "timeline.ex"), "w").write("\n".join(body))
    index.append({"id": f"m{n:03d}", "op": name, "line": i + 1, "was": lines[i].strip(), "now": (new or "(removed)").strip()})
json.dump(index, open(os.path.join(out, "index.json"), "w"), indent=1)
print(len(index), "mutants")
