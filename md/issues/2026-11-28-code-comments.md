# The code has comments; design commitment 5 says it carries none

| | |
|---|---|
| What was checked | `core/`, `gui/` and `tui/`: lines that are comments, and documentation attributes |
| Commit | `644cb13` |
| How | Counted with a search for lines beginning with `#` in `.ex` and `.exs` files, leaving out string interpolation, and for `@moduledoc` and `@doc`. Not read one by one |
| Rechecked | 2026-11-28, after the removal, run: Elixir's parser finds no comment in any `.ex` or `.exs` file of the three apps |
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
- **Status.** Fixed. The operator decided both points on 2026-11-28: documentation
  attributes are not comments and stay; the comments were removed and their text kept in
  [`md/docs/code-comments.md`](../docs/code-comments.md). The count above came from a
  text search and was 161; Elixir's parser finds 157, which is the number removed, with
  12 more from the stylesheet, the script and the demo agent. The eight excerpts the
  tutorial quotes are unchanged, because none of them quoted a comment.
