# The code has comments; design commitment 5 says it carries none

| | |
|---|---|
| What was checked | `core/`, `gui/` and `tui/`: lines that are comments, and documentation attributes |
| Commit | `644cb13` |
| How | Counted with a search for lines beginning with `#` in `.ex` and `.exs` files, leaving out string interpolation, and for `@moduledoc` and `@doc`. Not read one by one |
| Rechecked | not yet |
| Reported | here only; no tracker entry |

## 1. 161 comment lines and 87 documentation attributes, and no comments file

- **Location.**

  | app | comment lines | `@moduledoc` and `@doc` |
  |---|---|---|
  | `core/` | 87 | 47 |
  | `gui/` | 16 | 5 |
  | `tui/` | 58 | 35 |

  The demo agent, `core/priv/demo_agent/demo_acp.py`, has 2 more comment lines. The app's
  JavaScript, CSS and templates were not counted.
- **Expected.** [Design commitment 5](../docs/design-commitments.md): no comments, except
  one that is absolutely necessary, disclosed, and mirrored in a comments file.
- **Observed.** The code predates the commitment. There is no comments file.
- **What removing them touches.** The tutorial quotes eight excerpts of the code, and
  the issues filed on 2026-11-27 cite `timeline.ex` by line number. The tutorial's
  excerpt check will show which excerpts change. The line numbers in those issues are
  tied to commit `c387317` and stay true of it.
- **Status.** Waiting on the operator, a step in `next.md`: whether documentation
  attributes count, and whether the existing comments are removed or mirrored.
