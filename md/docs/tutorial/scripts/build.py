#!/usr/bin/env python3
"""Build the web edition of the tutorial from source/.

    python3 scripts/build.py            # writes index.html, part1..7.html, glossary.html, single.html

Inputs
    source/tutorial.md      the text: a start page and seven parts
    source/glossary.md      every term, its definition and the section that introduces it
    source/sources.md       the Sources section printed after the glossary
    assets/diagrams/*.svg   diagrams, inlined into the pages (scripts/make_diagrams.py writes them)
    solutions/*.exs         lab code is cut from these files, never retyped
    research/verify/*.txt   terminal output is cut from these transcripts, never retyped

This is the build script of an earlier tutorial by the same author, with the
titles changed and the interactives made optional. The page skeleton, the class names and
assets/style.css + assets/site.js follow that tutorial's web edition.

Needs the `markdown` package (pip install markdown). Reading the built pages needs nothing.
"""
import datetime
import html
import json
import os
import re
import sys
import textwrap

import markdown

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import steps  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source")
BRAND_LONG = "Stratta's architecture, from the process up"
BRAND_SHORT = "Stratta architecture"
TITLE_SUFFIX = "Stratta architecture tutorial"
FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">\n'
         '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600'
         '&family=IBM+Plex+Mono:wght@400;600&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;1,8..60,400&display=swap">')


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def slug(text):
    text = re.sub(r"<[^>]+>", "", text).lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text


def die(msg):
    sys.exit("build.py: " + msg)


# ---------------------------------------------------------------- source parsing

class Part:
    def __init__(self, n, title, blurb):
        self.n, self.title, self.blurb = n, title, blurb
        self.lines = []
        self.sections = []       # (anchor, heading text)
        self.html = ""

    @property
    def file(self):
        return "part%d.html" % self.n

    @property
    def anchor(self):
        return "part-%d" % self.n


def parse_tutorial():
    start, parts, cur = [], [], None
    for line in steps.fill(read("source", "tutorial.md")).split("\n"):
        m = re.match(r"@@part (\d+) \| (.+?) \| (.+)$", line)
        if m:
            cur = Part(int(m.group(1)), m.group(2).strip(), m.group(3).strip())
            parts.append(cur)
            continue
        (cur.lines if cur else start).append(line)
    return start, parts


# section number -> part, filled before rendering so cross-references can be resolved
SECTION_PART = {}
STATS = {"widget": 0, "diagram": 0, "example": 0, "words": 0}
FIG_IDS = set()


def index_sections(parts):
    for p in parts:
        for line in p.lines:
            m = re.match(r"### (\d+)\. (.+)$", line)
            if m:
                n = int(m.group(1))
                if n in SECTION_PART:
                    die("section %d defined twice" % n)
                SECTION_PART[n] = p
                p.sections.append(("s%d" % n, "%d. %s" % (n, m.group(2).strip())))
                continue
            m = re.match(r"### (.+)$", line)
            if m:
                p.sections.append((slug(m.group(1)), m.group(1).strip()))


def xrefs(text, single):
    """[[s12]] -> section 12, [[S12]] -> Section 12, [[n12]] -> 12, [[p3]] -> Part 3, [[g:slug|words]] -> glossary link."""
    def sec(m):
        n = int(m.group(2))
        if n not in SECTION_PART:
            die("cross-reference to missing section %d" % n)
        word = "Section" if m.group(1) == "S" else "section"
        href = ("#s%d" % n) if single else "%s#s%d" % (SECTION_PART[n].file, n)
        return '<a class="xref" href="%s">%s %d</a>' % (href, word, n)

    def num(m):
        n = int(m.group(1))
        if n not in SECTION_PART:
            die("cross-reference to missing section %d" % n)
        href = ("#s%d" % n) if single else "%s#s%d" % (SECTION_PART[n].file, n)
        return '<a class="xref" href="%s">%d</a>' % (href, n)

    def part(m):
        n = int(m.group(1))
        href = ("#part-%d" % n) if single else "part%d.html" % n
        return '<a class="xref" href="%s">Part %d</a>' % (href, n)

    def gloss(m):
        href = ("#g-%s" % m.group(1)) if single else "glossary.html#g-%s" % m.group(1)
        return '<a href="%s">%s</a>' % (href, m.group(2))

    text = re.sub(r"\[\[([sS])(\d+)\]\]", sec, text)
    text = re.sub(r"\[\[n(\d+)\]\]", num, text)
    text = re.sub(r"\[\[p(\d+)\]\]", part, text)
    text = re.sub(r"\[\[g:([a-z0-9-]+)\|([^\]]+)\]\]", gloss, text)
    return text


def md(text):
    out = markdown.markdown(text, extensions=["tables", "sane_lists"])
    out = out.replace("<table>", '<div class="table-wrap"><table>').replace("</table>", "</table></div>")
    return out


def inline(text):
    out = md(text).strip()
    if out.startswith("<p>") and out.endswith("</p>") and out.count("<p>") == 1:
        out = out[3:-4]
    return out


def cut(spec):
    """@file lang path | first-line substring | last-line substring  ->  (lang, code)."""
    m = re.match(r"@file (\S+) (\S+) \| (.+?) \| (.+)$", spec)
    if not m:
        die("bad @file line: " + spec)
    lang, path, first, last = m.group(1), m.group(2), m.group(3).strip(), m.group(4).strip()
    extra = re.search(r" \+(\d+)$", last)          # "marker +2": two more lines after the marker line
    if extra:
        last = last[:extra.start()]
    lines = read(path).split("\n")
    try:
        i = next(k for k, l in enumerate(lines) if first in l)
        j = next(k for k in range(i, len(lines)) if last in lines[k])
    except StopIteration:
        die("could not cut %r .. %r from %s" % (first, last, path))
    j += int(extra.group(1)) if extra else 0
    # transcripts keep the build service's timestamps on disk; the pages show the lines without them
    body = [re.sub(r"^\d{4}-\d\d-\d\dT[\d:.]+Z ", "", l) for l in lines[i:j + 1]]
    return lang, "\n".join(body), path


def fig_open(kind, fid, extra=""):
    if fid in FIG_IDS:
        die("figure id used twice: " + fid)
    FIG_IDS.add(fid)
    STATS[kind] += 1
    return '<figure class="ik-figure is-%s" id="%s"%s>' % (kind, fid, extra)


def directive(head, body, single):
    args = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', head))
    args = {k: v.strip('"') for k, v in args.items()}
    kind = head.split()[0]
    if kind == "note":
        return '<p class="ik-note">%s</p>' % inline(xrefs(" ".join(body), single))
    if kind == "diagram":
        svg = read("assets", "diagrams", args["file"]).strip()
        cap = inline(xrefs(" ".join(body), single))
        return (fig_open("diagram", args["id"]) + '<div class="ik-body"><div class="diagram-scroll">' + svg +
                "\n</div></div><figcaption>%s</figcaption></figure>" % cap)
    if kind == "widget":
        cap = inline(xrefs(" ".join(body), single))
        extra = ' data-widget="%s" data-opts="%s"' % (args["name"], html.escape(args.get("opts", "{}"), quote=True))
        return (fig_open("widget", args["id"], extra) +
                '<div class="ik-body"><noscript><p class="ik-note">This interactive needs JavaScript. '
                'The text around it is complete without it.</p></noscript></div>'
                "<figcaption>%s</figcaption></figure>" % cap)
    if kind == "example":
        title = cap = note = ""
        blocks, k = [], 0
        while k < len(body):
            line = body[k]
            if line.startswith("title:"):
                title = line[6:].strip()
            elif line.startswith("caption:"):
                cap = line[8:].strip()
            elif line.startswith("note:"):
                note = line[5:].strip()
            elif line.startswith("@file"):
                lang, code, path = cut(line)
                blocks.append((lang, code))
            elif line.startswith("```"):
                lang = line[3:].strip() or "text"
                k += 1
                code = []
                while not body[k].startswith("```"):
                    code.append(body[k])
                    k += 1
                blocks.append((lang, "\n".join(code)))
            elif line.strip():
                die("unexpected line in example %s: %s" % (args.get("id"), line))
            k += 1
        out = fig_open("example", args["id"]) + '<div class="ik-body"><div class="ex-title">%s</div>' % inline(title)
        for lang, code in blocks:
            code = textwrap.dedent(code)          # excerpts lose the indentation they had in their file
            out += '<pre><code class="language-%s">%s\n</code></pre>\n' % (lang, html.escape(code, quote=False))
        if note:
            out += '<p class="ik-note" style="padding:0.5rem 1rem 0.75rem">%s</p>' % inline(xrefs(note, single))
        return out + "</div><figcaption>%s</figcaption></figure>" % inline(xrefs(cap, single))
    die("unknown directive: " + head)


def render(lines, single, count=False):
    """Markdown plus ::: directives -> HTML. Headings get ids."""
    out, buf, k = [], [], 0

    def flush():
        if not buf:
            return
        text = "\n".join(buf)
        if count:
            prose = re.sub(r"\[\[[^\]]*\|([^\]]*)\]\]", r"\1", text)
            STATS["words"] += len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'’.-]*", prose))
        out.append(md(xrefs(text, single)))
        del buf[:]

    while k < len(lines):
        line = lines[k]
        if line.startswith(":::") and line.strip() != ":::":
            flush()
            head, body = line[3:].strip(), []
            k += 1
            while lines[k].strip() != ":::":
                body.append(lines[k])
                k += 1
            out.append(directive(head, body, single))
        else:
            buf.append(line)
        k += 1
    flush()
    htm = "\n".join(out)

    def h3(m):
        inner = m.group(1)
        n = re.match(r"(\d+)\. ", inner)
        return '<h3 id="%s">%s</h3>' % ("s" + n.group(1) if n else slug(inner), inner)

    htm = re.sub(r"<h3>(.*?)</h3>", h3, htm)
    htm = re.sub(r"<h2>(.*?)</h2>", lambda m: '<h2 id="%s">%s</h2>' % (slug(m.group(1)), m.group(1)), htm)
    return htm


# ---------------------------------------------------------------- glossary

def parse_glossary():
    terms, cur = [], None
    for line in read("source", "glossary.md").split("\n"):
        if line.startswith("## "):
            cur = {"term": line[3:].strip(), "section": None, "match": None, "text": []}
            terms.append(cur)
        elif cur is not None and line.startswith("section:"):
            cur["section"] = int(line.split(":")[1])
        elif cur is not None and line.startswith("match:"):
            cur["match"] = line.split(":", 1)[1].strip()
        elif cur is not None:
            cur["text"].append(line)
    for t in terms:
        t["id"] = "g-" + slug(t["term"])
        if t["section"] not in SECTION_PART:
            die("glossary term %r names missing section %r" % (t["term"], t["section"]))
    ids = [t["id"] for t in terms]
    if len(set(ids)) != len(ids):
        die("duplicate glossary ids")
    terms.sort(key=lambda t: re.sub(r"[^a-z0-9]", "", t["term"].lower()))
    return terms


def render_glossary(terms, single):
    letters = []
    for t in terms:
        c = re.sub(r"[^a-z0-9]", "", t["term"].lower())[0].upper()
        if c not in letters:
            letters.append(c)
    base = "" if single else "glossary.html"
    out = ['<h1 id="glossary">Glossary</h1>',
           "<p>Every technical term this tutorial uses, A to Z, with the section that introduces it. "
           "Built from <code>source/glossary.md</code>; the site check confirms that each term appears in "
           "<strong>bold</strong> in the section named here.</p>",
           "<p><strong>Jump to:</strong> " + " · ".join(
               '<a href="%s#gl-%s">%s</a>' % (base, c.lower(), c) for c in letters) + "</p>"]
    seen = None
    for t in terms:
        c = re.sub(r"[^a-z0-9]", "", t["term"].lower())[0].upper()
        if c != seen:
            # in the one-page edition the letter headings stay out of the "on this page" rail
            tag = "h4" if single else "h3"
            out.append('<%s id="gl-%s" class="gl-letter">%s</%s>' % (tag, c.lower(), c, tag))
            seen = c
        n = t["section"]
        href = ("#s%d" % n) if single else "%s#s%d" % (SECTION_PART[n].file, n)
        body = md(xrefs("\n".join(t["text"]).strip(), single)).strip()
        intro = ' <em>Introduced in section <a href="%s">%d</a>.</em></p>' % (href, n)
        body = body[:-4] + intro if body.endswith("</p>") else body + "<p>" + intro
        out.append('<h4 id="%s">%s</h4>\n%s' % (t["id"], inline(t["term"]), body))
    out.append('<h2 id="sources">Sources</h2>')
    out.append(render(read("source", "sources.md").split("\n"), single))
    return "\n".join(out)


# ---------------------------------------------------------------- page shell

def widget_files():
    d = os.path.join(ROOT, "assets", "widgets")
    if not os.path.isdir(d):
        return []
    return sorted(f for f in os.listdir(d) if f.endswith(".js"))


def topbar(parts, current, single):
    def link(href, label, key):
        cur = ' aria-current="page"' if key == current else ""
        return '<a href="%s"%s>%s</a>' % (href, cur, label)
    if single:
        links = [link("#top", "Start", "index")] + [link("#part-%d" % p.n, "Part %d" % p.n, p.n) for p in parts]
        links.append(link("#glossary", "Glossary", "glossary"))
        home = "#top"
    else:
        links = [link("index.html", "Start", "index")] + [link(p.file, "Part %d" % p.n, p.n) for p in parts]
        links.append(link("glossary.html", "Glossary", "glossary"))
        home = "index.html"
    return ('<header class="topbar"><div class="topbar-inner"><a class="brand" href="%s">'
            '<span class="brand-long">%s</span><span class="brand-short">%s</span></a>'
            '<nav aria-label="Parts">%s</nav></div></header>' % (home, BRAND_LONG, BRAND_SHORT, "".join(links)))


def footer(today):
    return ('<footer class="site-footer"><p class="ik-note">Generated from <code>source/tutorial.md</code> on %s by '
            "<code>scripts/build.py</code>. Reading these pages sends nothing anywhere.</p></footer>"
            % today)


def pager(prev, nxt):
    out = '<nav class="pager">'
    if prev:
        out += '<a class="prev" href="%s"><small>Previous</small>%s</a>' % prev
    if nxt:
        out += '<a class="next" href="%s"><small>Next</small>%s</a>' % nxt
    return out + "</nav>"


def page(title, parts, current, main, single=False):
    if single:
        css = "<style>\n%s\n</style>" % read("assets", "style.css")
        js = "".join("<script>\n%s\n</script>\n" % read("assets", "widgets", f) for f in widget_files())
        js += "<script>\n%s\n</script>" % read("assets", "site.js")
    else:
        css = '<link rel="stylesheet" href="assets/style.css">'
        js = "".join('<script src="assets/widgets/%s"></script>' % f for f in widget_files())
        js += '\n<script src="assets/site.js"></script>'
    return ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            "<title>%s · %s</title>\n%s\n%s\n</head>\n<body%s>\n%s\n<div class=\"page\">\n<main class=\"prose\">\n%s\n</main>\n"
            '<aside class="rail" aria-label="On this page"><h2>On this page</h2><ol></ol></aside>\n</div>\n%s\n</body>\n</html>\n'
            % (title, TITLE_SUFFIX, FONTS, css, ' id="top"' if single else "", topbar(parts, current, single), main, js))


def contents(parts, single):
    out = []
    for p in parts:
        href = ("#part-%d" % p.n) if single else p.file
        out.append('<p><strong><a href="%s">Part %d. %s</a></strong> (%s)</p>\n<ul>' % (href, p.n, p.title, p.blurb))
        for anchor, text in p.sections:
            h = ("#" + anchor) if single else "%s#%s" % (p.file, anchor)
            out.append('<li><a href="%s">%s</a></li>' % (h, text))
        out.append("</ul>")
    g = "#glossary" if single else "glossary.html#glossary"
    s = "#sources" if single else "glossary.html#sources"
    out.append('<p><a href="%s">Glossary</a> · <a href="%s">Sources</a></p>' % (g, s))
    return "\n".join(out)


def build():
    today = datetime.date.today().strftime("%-d %b %Y")
    start, parts = parse_tutorial()
    index_sections(parts)
    terms = parse_glossary()
    written = {}

    for single in (False, True):
        FIG_IDS.clear()
        for key in STATS:
            STATS[key] = 0
        start_html = render(start, single, count=True)
        for p in parts:
            p.html = render(p.lines, single, count=True)
        gloss_html = render_glossary(terms, single)
        stats = ('<p class="ik-note">This edition is generated from the tutorial source, source/tutorial.md '
                 "(%d words). %d diagrams, %d code examples, %d glossary terms.</p>"
                 % (STATS["words"], STATS["diagram"], STATS["example"], len(terms)))
        start_html = start_html.replace("<p>@@contents</p>", contents(parts, single)) + stats

        if single:
            main = start_html
            for p in parts:
                main += ('\n<p class="kicker" id="%s">Part %d</p><h1 id="part-%d-%s">%s</h1>\n%s'
                         % (p.anchor, p.n, p.n, slug(p.title), p.title, p.html))
            main += "\n<section>" + gloss_html + "</section>\n" + footer(today)
            written["single.html"] = page("One-page edition", parts, "index", main, single=True)
            continue

        nxt = (parts[0].file, "Part %d. %s" % (parts[0].n, parts[0].title))
        written["index.html"] = page("Start here", parts, "index",
                                     start_html + "\n" + pager(None, nxt) + "\n" + footer(today))
        for i, p in enumerate(parts):
            prev = ("index.html", "Start here") if i == 0 else (parts[i - 1].file, "Part %d. %s" % (parts[i - 1].n, parts[i - 1].title))
            nxt = ("glossary.html", "Glossary and sources") if i == len(parts) - 1 else (parts[i + 1].file, "Part %d. %s" % (parts[i + 1].n, parts[i + 1].title))
            main = ('<p class="kicker">Part %d</p><h1 id="part-%d-%s">%s</h1>\n%s\n%s\n%s'
                    % (p.n, p.n, slug(p.title), p.title, p.html, pager(prev, nxt), footer(today)))
            written[p.file] = page("Part %d. %s" % (p.n, p.title), parts, p.n, main)
        last = parts[-1]
        written["glossary.html"] = page("Glossary", parts, "glossary",
                                        gloss_html + "\n" + pager((last.file, "Part %d. %s" % (last.n, last.title)), None)
                                        + "\n" + footer(today))
        counts = dict(STATS, terms=len(terms), sections=len(SECTION_PART))

    for name, text in written.items():
        with open(os.path.join(ROOT, name), "w", encoding="utf-8") as f:
            f.write(text)
    nums = steps.numbers()
    with open(os.path.join(ROOT, "research", "build-steps.txt"), "w", encoding="utf-8") as f:
        f.write("".join("%s\t%d\n" % (k, nums[k]) for k in sorted(nums)))
    with open(os.path.join(ROOT, "research", "build-stats.json"), "w", encoding="utf-8") as f:
        json.dump(counts, f, indent=2, sort_keys=True)
        f.write("\n")
    print("built %d pages: %s" % (len(written), json.dumps(counts, sort_keys=True)))


if __name__ == "__main__":
    build()
