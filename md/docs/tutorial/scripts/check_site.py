#!/usr/bin/env python3
"""Check the built pages. Run after scripts/build.py; exits non-zero on any failure.

    python3 scripts/check_site.py

Checks
  1. every internal link and anchor resolves, in the multi-page edition and in single.html
  2. every glossary term appears in <strong> in the section the glossary names
     (text before a part's first numbered section counts as that section)
  3. every figure has a caption and a unique id; every widget named has a script
  4. no page needs the network to be read: the only external references are the font links
  5. no placeholder text is left
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build  # noqa: E402

ROOT = build.ROOT
errors = []


def err(msg):
    errors.append(msg)


def ids_of(text):
    return set(re.findall(r'\sid="([^"]+)"', text))


def strip_tags(text):
    return re.sub(r"<[^>]+>", "", text)


_, _parts = build.parse_tutorial()
pages = ["index.html", "glossary.html"] + [p.file for p in _parts]
texts = {}
for name in pages + ["single.html"]:
    path = os.path.join(ROOT, name)
    if not os.path.exists(path):
        err("missing page " + name)
        continue
    with open(path, encoding="utf-8") as f:
        texts[name] = f.read()

# 1. links
for name, text in texts.items():
    for href in re.findall(r'href="([^"]+)"', text):
        if href.startswith(("http://", "https://", "mailto:")):
            continue
        target, _, frag = href.partition("#")
        target = target or name
        if target.endswith((".css", ".js", ".svg")):
            if not os.path.exists(os.path.join(ROOT, target)):
                err("%s: missing asset %s" % (name, target))
            continue
        if target not in texts:
            err("%s: link to missing page %s" % (name, href))
            continue
        if frag and frag not in ids_of(texts[target]):
            err("%s: link to missing anchor %s" % (name, href))
    for src in re.findall(r'<script src="([^"]+)"', text):
        if not os.path.exists(os.path.join(ROOT, src)):
            err("%s: missing script %s" % (name, src))

# 2. glossary terms are introduced, in bold, where the glossary says
start, parts = build.parse_tutorial()
build.index_sections(parts)
terms = build.parse_glossary()
section_text = {}
for p in parts:
    cur, first = None, None
    lead = []
    for line in p.lines:
        m = re.match(r"### (\d+)\. ", line)
        if m:
            cur = int(m.group(1))
            if first is None:
                first = cur
                section_text[cur] = list(lead)
            else:
                section_text[cur] = []
        elif line.startswith("### "):
            pass                      # an unnumbered closing section stays with the section before it
        if cur is None:
            lead.append(line)
        else:
            section_text[cur].append(line)
for t in terms:
    want = (t["match"] or t["term"]).lower().replace("`", "")
    body = "\n".join(section_text.get(t["section"], []))
    bolds = [b.lower().replace("`", "") for b in re.findall(r"\*\*([^*]+)\*\*", body)]
    if not any(want in b for b in bolds):
        err("glossary: %r is not in bold in section %d" % (t["term"], t["section"]))

# 3. figures
for name in pages:
    text = texts.get(name, "")
    for fig in re.findall(r"<figure class=\"ik-figure[^>]*>.*?</figure>", text, flags=re.S):
        if "<figcaption>" not in fig or "<figcaption></figcaption>" in fig:
            err("%s: figure without caption" % name)
        w = re.search(r'data-widget="([^"]+)"', fig)
        if w and not os.path.exists(os.path.join(ROOT, "assets", "widgets", w.group(1) + ".js")):
            err("%s: widget %s has no script" % (name, w.group(1)))
    figs = re.findall(r'<figure class="ik-figure[^"]*" id="([^"]+)"', text)
    if len(figs) != len(set(figs)):
        err("%s: duplicate figure id" % name)

# 4. nothing but the font links leaves the page
for name, text in texts.items():
    for url in re.findall(r'(?:src|href)="(https?://[^"]+)"', text):
        if not url.startswith(("https://fonts.googleapis.com", "https://fonts.gstatic.com")):
            err("%s: external reference %s" % (name, url))

# 5. placeholders
for name, text in texts.items():
    for bad in ("TODO", "FIXME", "@@", "[[", "lorem"):
        if bad in strip_tags(text):
            err("%s: leftover %r" % (name, bad))

if errors:
    print("check_site.py: %d problem(s)" % len(errors))
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("check_site.py: ok (%d pages, %d glossary terms, %d sections)" % (len(texts), len(terms), len(build.SECTION_PART)))
