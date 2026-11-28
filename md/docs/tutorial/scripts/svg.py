#!/usr/bin/env python3
"""The drawing primitives behind scripts/make_diagrams.py.

Copied from an earlier tutorial's scripts/make_diagrams.py,
so that the diagrams of both tutorials share one look.

The diagrams are drawn from a few primitives so that they share one look. Colours and
fonts are the CSS variables of assets/style.css, so the diagrams follow the page's
light and dark themes. Each file is inlined into a page by scripts/build.py.
"""
import os
from html import escape

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "diagrams")

KINDS = {
    "plain": ("var(--paper)", "var(--ink-2)"),
    "panel": ("var(--paper-2)", "var(--rule)"),
    "accent": ("var(--accent-soft)", "var(--accent)"),
    "warm": ("var(--warm-soft)", "var(--warm)"),
    "good": ("var(--good-soft)", "var(--good)"),
    "bad": ("var(--bad-soft)", "var(--bad)"),
}


class Svg:
    def __init__(self, name, w, h, title):
        self.name, self.w, self.h, self.title = name, w, h, title
        self.p = name.replace("-", "")[:6]
        self.body = []

    def text(self, x, y, s, size=13, weight=400, fill="var(--ink)", anchor="start", mono=False, italic=False):
        fam = "var(--font-mono)" if mono else "var(--font-display)"
        style = ' font-style="italic"' if italic else ""
        self.body.append('<text x="%s" y="%s" font-family="%s" font-size="%s" font-weight="%s" fill="%s" text-anchor="%s"%s>%s</text>'
                         % (x, y, fam, size, weight, fill, anchor, style, escape(s)))

    def box(self, x, y, w, h, label=None, sub=None, kind="plain", dashed=False, mono=False, size=13, rx=5):
        fill, stroke = KINDS[kind]
        dash = ' stroke-dasharray="5 4"' if dashed else ""
        self.body.append('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" stroke="%s" stroke-width="1.5"%s/>'
                         % (x, y, w, h, rx, fill, stroke, dash))
        cx = x + w / 2
        if label and sub:
            self.text(cx, y + h / 2 - 3, label, size=size, weight=600, anchor="middle", mono=mono)
            self.text(cx, y + h / 2 + 14, sub, size=11.5, fill="var(--ink-2)", anchor="middle")
        elif label:
            self.text(cx, y + h / 2 + 4.5, label, size=size, weight=600, anchor="middle", mono=mono)

    def arrow(self, x1, y1, x2, y2, label=None, color="ink", dashed=False, lx=None, ly=None, anchor="middle", both=False):
        stroke = {"ink": "var(--ink-2)", "accent": "var(--accent)", "good": "var(--good)", "bad": "var(--bad)",
                  "warm": "var(--warm)"}[color]
        dash = ' stroke-dasharray="5 4"' if dashed else ""
        start = ' marker-start="url(#%s-%s)"' % (self.p, color) if both else ""
        self.body.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.5"%s marker-end="url(#%s-%s)"%s/>'
                         % (x1, y1, x2, y2, stroke, dash, self.p, color, start))
        if label:
            self.text(lx if lx is not None else (x1 + x2) / 2, ly if ly is not None else (y1 + y2) / 2 - 7, label,
                      size=11.5, fill="var(--ink-2)", anchor=anchor)

    def line(self, x1, y1, x2, y2, stroke="var(--rule)", width=1.5, dashed=False):
        dash = ' stroke-dasharray="5 4"' if dashed else ""
        self.body.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s"%s/>' % (x1, y1, x2, y2, stroke, width, dash))

    def circle(self, x, y, r, kind="accent"):
        fill, stroke = KINDS[kind]
        self.body.append('<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="1.5"/>' % (x, y, r, fill, stroke))

    def raw(self, s):
        self.body.append(s)

    def save(self):
        markers = ""
        for color, var in (("ink", "var(--ink-2)"), ("accent", "var(--accent)"), ("good", "var(--good)"),
                           ("bad", "var(--bad)"), ("warm", "var(--warm)")):
            markers += ('<marker id="%s-%s" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" '
                        'markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="%s"/></marker>'
                        % (self.p, color, var))
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" aria-labelledby="%s-title">\n'
               '  <title id="%s-title">%s</title>\n  <defs>%s</defs>\n  %s\n</svg>\n'
               % (self.w, self.h, self.p, self.p, escape(self.title), markers, "\n  ".join(self.body)))
        with open(os.path.join(OUT, self.name + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg)
