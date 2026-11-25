---
type: plan
status: proposed
created: 2026-11-25
---

# Hyperlinks in the terminal client

## Summary

The terminal client prints URLs and file paths as plain text. A pull request URL from
`stratta ship`, a path in a tool call, a file in the diff view: all of them have to be
selected and copied by hand. OSC 8 is the escape sequence that makes a span of text a
link, with the URL hidden behind a label, and terminals that do not implement it draw the
label and discard the sequence.

This plan adds one link primitive to `Stratta.TUI.Render` and uses it for the links
Stratta itself generates. It is small, self-contained, and independent of the other plans.

Like the status reports, it stays neutral about terminals: Stratta emits the sequence and
makes no attempt to detect who is listening. Nothing here names a terminal, per the
decision recorded in `next.md`.

## What happens today

Checked in the code on 2026-11-25:

- `Stratta.TUI.Render` builds each row as a list of `{style, text}` spans. `frame/3` turns
  rows into bytes, mapping each style through an `@sgr` table and resetting after it.
- `frame/3` already takes a cursor as `{row, col}` (1-based) or hides it, so the frame
  layer is the one place that writes escape sequences.
- `wrap/2` and `fit/2` measure with `String.length/1`, one cell per character.
- Nothing emits OSC 8. PR URLs, paths in tool calls and diff file headers are plain text.
- `Stratta.TUI.Status` already emits OSC 7501 and OSC 9;4 on the same argument this plan
  relies on: a terminal that does not know a sequence discards it.

## Design

- **A link is an annotation on a span, not bytes in the text.** Spans gain a third shape,
  `{style, text, url}`, beside the existing `{style, text}`. Only `frame/3` expands it
  into `ESC ] 8 ; ; url ESC \` + styled label + `ESC ] 8 ; ; ESC \`.
- **Width math never sees the escapes.** This is the whole reason for annotating rather
  than inlining. `wrap/2`, `fit/2` and `frame/3`'s own column accounting measure the
  label only. Inlining escapes into text would let `fit/2` truncate a line in the middle
  of a sequence and leave the rest of the pane hyperlinked.
- **Only Stratta's own links become links.** A label can say one thing while its URL points
  somewhere else, so a link built from agent-controlled text is a phishing primitive.
  Agent output keeps its bare URLs, which terminals linkify themselves. Stratta wraps only
  URLs it produced: a PR it opened, a path it resolved inside the project.
- **No capability detection.** No termcap sniffing and no allowlist. `STRATTA_HYPERLINKS=0`
  turns the sequences off for anyone whose terminal mangles them, matching how
  `STRATTA_STATUS_HOOK` and `STRATTA_OPENER` are configured.
- **Paths are `file://` URLs**, absolute, built from the thread's working folder. A link to
  a file is useful beyond clicking: a terminal that previews links can show the file
  without touching the pane.
- **One-shot commands too.** `stratta ship` prints its PR URL from `Stratta.TUI.CLI`, not
  from a view, so the primitive has to be callable outside the frame loop. `--json` output
  is never decorated.

## Work

### Phase 1: the primitive (small)

- `Render`: accept `{style, text, url}` spans; expand them in `frame/3`; honour
  `STRATTA_HYPERLINKS=0`. A `link/3` helper for building spans.
- `render_test.exs`: a link span emits the open and close sequences around the label; the
  label alone is what counts toward the width; a row truncated by `fit/2` never emits a
  half sequence; the sequences vanish when the variable is `0`.

### Phase 2: the links themselves

- PR URLs in the viewer's timeline, the ship output and `stratta ship` / `push`.
- File paths in the diff view's file headers and in tool call titles, as `file://`.
- A plain-text helper for `CLI` so one-shot output can link without a frame.

### Phase 3: documentation

- `tui/README.md`: a short section beside "Telling the terminal what the agent is doing",
  with the same "terminals ignore what they do not know" note, and `STRATTA_HYPERLINKS`.

## Open questions

- Whether to link paths in the timeline's tool calls as well as the diff view. The diff
  view's paths are resolved against the thread's folder already; a tool call's path is
  whatever the agent wrote, which may not resolve, and is agent-controlled text. Leaning
  towards the diff view only in Phase 2.
- Whether `fit/2` should keep a truncated link clickable (link the shortened label) or
  drop the link with the text. Linking the shortened label seems right and is cheaper.

## Findings

Verified on 2026-11-25 in a terminal that implements OSC 8: a label-and-URL span rendered
as the label alone and resolved to a real link in the terminal's own cell model, while a
bare URL on the next line did not, confirming that bare-URL clicking is the terminal's
text scanning and not OSC 8. The zero-width cost of the sequence is what Phase 1's width
tests exist to protect.
