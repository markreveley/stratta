---
type: plan
kind: need
status: proposed
created: 2026-11-25
---

# A composer you can edit

## Summary

The viewer's composer (the `›` input at the bottom of `stratta attach`) is one line of
text that only grows at the end. A long message runs off the side, newlines collapse to a
`⏎` glyph, and there is no way to move the cursor back into what you typed: the only edits
are backspace, delete-last-word and clear. For anything longer than a sentence it is
easier to leave the viewer and use `stratta send`.

This plan makes it a small wrapped editor: the text wraps across as many rows as it needs,
the cursor moves by character, word and line, and a newline can be inserted on purpose.
The known limit in `tui/README.md` ("the composer is a single line with no cursor
movement") is exactly this.

Terminal only. The app's composer is a browser textarea and already does all of this.

## Why this exists

Kind: **need**.

Listed among the known limits in `tui/README.md`: the composer is a single line with no
cursor movement.

## What happens today

Checked in the code on 2026-11-25:

- `Stratta.TUI.Viewer` keeps the text as a plain string in `input`. `{:char, c}` appends,
  `{:paste, text}` appends with `\r` turned into `\n`, backspace slices the last grapheme,
  `ctrl_u` clears, `ctrl_w` strips a trailing word with a regex.
- Rendering replaces `\n` with `⏎`, then keeps the last `w - 3` characters, so a long line
  scrolls horizontally. The cursor is reported as `{h - 1, 3 + length}`: always at the end.
- `@chrome 4` reserves header, status row, one composer row and hints. The composer cannot
  be taller than one row.
- `Stratta.TUI.Keys` parses `:left` and `:right`, but the viewer has no clause for them, so
  they reach the catch-all and do nothing. `:up` / `:down` scroll the timeline by 3,
  `:pgup` / `:pgdn` by a page, `:home` jumps to the top and `:end` follows the latest.
- `:enter` submits, `:alt_enter` and `:ctrl_s` submit as a steer. No key inserts a newline.
- `Keys` drops every other control byte (`when c < 32`) and discards Alt-prefixed
  sequences, so word-motion and modified-arrow keys do not currently arrive at all.
- `Render.wrap/2` already wraps text to a width, and `Render.frame/3` already places a
  1-based cursor anywhere or hides it. Both are reusable as they are.
- The dashboard and the diff view have no composer, so nothing else is affected.

## Design

- **A pure module.** `Stratta.TUI.Composer` holds `%{text: String.t(), cursor: integer}`
  with the cursor as a grapheme index, and exposes insert, delete, motion and a
  `layout/2` that returns wrapped rows plus the cursor's row and column. It follows the
  repo's existing pure-module pattern (`Timeline`, `Render`, `Keys`), so the whole feature
  is testable without a terminal.
- **The composer grows, the timeline shrinks.** `@chrome` becomes `3 + composer height`,
  capped (six rows is a reasonable cap) after which the composer scrolls its own rows and
  keeps the cursor visible. The scroll limit is already derived from the chrome, so it
  follows automatically.
- **Readline keys, not the arrow keys the timeline owns.** This is the only real design
  decision, because the keys that would move a cursor are already scrolling the timeline.
  Taking them back would be a regression for anyone reading a long thread.

  | key | does | conflict |
  | --- | --- | --- |
  | left / right | cursor by grapheme | none; unused today |
  | ctrl-a / ctrl-e | start / end of the composer line | none; new |
  | alt-b / alt-f, ctrl-left / ctrl-right | cursor by word | none; new |
  | ctrl-k | delete to end of line | none; new |
  | ctrl-j | insert a newline | none; new |
  | up / down | move between composer rows **only when the composer has more than one row**, and fall through to timeline scroll at the first and last row | keeps the single-line case exactly as it is today |
  | home / end / pgup / pgdn | unchanged: the timeline | no regression |
  | ctrl-u / ctrl-w | become cursor-relative: to line start, word before cursor | same keys, readline behaviour |

- **Shift+enter is not available.** Most terminals send the same byte for enter and
  shift+enter unless a modified-key protocol is negotiated, which this client does not do.
  `ctrl-j` is the portable newline. `alt-enter` keeps its current meaning, steer.
- **Submit is unchanged.** `enter` sends the trimmed text, `alt-enter` and `ctrl-s` steer
  it. A message keeps its newlines: `Stratta.ThreadServer` passes text through untouched,
  so multi-line messages already work on the wire.
- **Paste inserts at the cursor.** It already arrives as one `{:paste, text}` event,
  including across reads, so this is just a different insertion point.
- **`y` / `n` still answer approvals only when the composer is empty**, which the current
  guard already expresses as `input: ""`.
- **The one-cell-per-character assumption stays.** The cursor column inherits it, so a wide
  character still misaligns, exactly as the README already warns for column widths. A
  display-width function is the single fix for both and is deliberately out of scope here;
  fixing it inside the composer alone would make the two disagree.

## Work

### Phase 1: the module (small, pure)

- `Stratta.TUI.Composer`: state, insert, backspace, delete, `ctrl-k` / `ctrl-u` / `ctrl-w`,
  motion by grapheme, word and line, newline insert, and `layout/2`.
- A test file of its own: text and cursor after each operation, wrapping at a width,
  cursor row and column including the position at the end of a wrapped row and on an empty
  trailing line, and multi-line paste.

### Phase 2: the keys

- `Keys`: `ctrl_a`, `ctrl_e`, `ctrl_j`, `ctrl_k`, `ctrl_b`, `ctrl_f`, `alt_b`, `alt_f`,
  `ctrl_left`, `ctrl_right`. The `c < 32` catch-all and the Alt-dropping clause both
  silently swallow these today, so each needs an explicit entry ahead of them.
- `keys_test.exs`: each new sequence, and the existing ones still parse unchanged.

### Phase 3: the viewer

- Swap `input` for a `Composer`; dynamic `@chrome`; render the wrapped rows with the
  prompt on the first; return the real cursor position; route the keys, including the
  up/down fall-through rule and the composer's own row scrolling.
- `render_test.exs`: a wrapped composer's rows and cursor; up/down scrolling the timeline
  when the composer is one row and moving the cursor when it is several.
- Drive it through a pseudo-terminal for the real check, per the note in `next.md`.

### Phase 4: documentation

- `tui/README.md`: the viewer's key table gains the editing keys; the known-limits
  paragraph drops the composer and keeps the wide-character one.

## Open questions

- The six-row cap is a guess. It could also be a fraction of the pane height, which
  behaves better in a short split.
- Whether `ctrl-k` on an empty line should join the next one. Leaning no: delete to end of
  line, nothing more.
- Interaction with [`slash-commands.md`](slash-commands.md). Its Phase 3 suggests commands
  in this composer, and a suggestion list wants both rows above the composer and the arrow
  keys for selection. The two plans need one agreed key precedence; whichever lands second
  should read the other's rule rather than invent its own. Suggestion selection probably
  wins the arrow keys while the list is open.
