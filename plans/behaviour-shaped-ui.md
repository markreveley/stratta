---
type: plan
kind: experiment
status: proposed
created: 2026-11-25
---

# Surfaces drawn from behaviour

## Summary

Stratta's screens are written by hand, one at a time: a button in the app, a key in the
viewer, a verb in the client, each added three times. Two plans already in this repository
break that pattern in one place each —
[slash commands](slash-commands.md) renders a list the agent advertises, and
[code mode](code-mode-orchestrator.md) Phase 0 gives every `Stratta.API` operation a spec
with its arguments, its result and whether it only reads. This plan takes that second
registry and makes it the source of a command palette, and then does the same for the
state a [policy](policy-as-actions.md) skill holds.

The test of whether this is worth doing is narrow and worth stating: **adding one
capability should add it to the app, the client and the model-facing tool list at once.**
If it only ever saves work in one of the three, it is not worth generating anything.

## Why this exists

Kind: **experiment**.

The fact behind it is in the code: a capability is added three times, in the app, the
viewer and the client. Whether generating all three from one registry saves more than it
costs is not known, and the test in the summary says when to stop. Phase 1, the parent
link and the tree, is ordinary work with a use today: a hand-off already makes pairs of
threads with nothing joining them.

## What it draws, and from what

- **A command palette, from the operation specs.** [The app first](gui-first.md) puts a
  parser and a `command.run` operation in `core/`, and a command bar in the app, so the
  language already exists in one place and both front ends already speak it. This plan
  renders it rather than repeating it: the palette, the generated form and the
  applicability rule sit on top of that parser, and nothing here defines a second path to
  an operation. Code mode's Phase 0 produces the specs
  and `stratta ops`. The same specs give the app's palette and the viewer's, with a
  generated form per operation from its argument schema, and the read-only flag deciding
  what needs confirming. The precedence rule the composer plans settle — agent slash
  commands first, Stratta's own commands after — holds here too.
- **Only what applies now.** An operation or command that cannot be run on this thread in
  this state is not offered. Today that is `if` statements in a template; here it is a
  property of the thread, asked once.
- **A card per skill.** A policy skill holds its rules; a budget skill would hold its
  limits. Because a skill's state carries its own schema, a card can be rendered for state
  no screen was written for: fields from the schema, values from the state, edits back
  through the skill's own actions. The hand-written card stays for the two or three that
  are looked at daily.
- **Threads that contain threads.** When a thread can spawn a thread, the sidebar is a
  tree and a parent's status dot is the roll-up of its children: *waiting, because one of
  its children is*. This is the part with no equivalent anywhere else, and it needs a
  parent link on the thread record to exist at all.
- **What is about to happen.** Where a decision produces described effects before they
  run, the timeline can carry them as a pending item with the same approve and deny the
  tool calls already have.

## Design notes

- One registry, three renderers. The registry is the operation specs plus the skills a
  thread has; the renderers are the app, the viewer and the tool list offered to a model.
  No renderer may hold knowledge the registry does not have.
- Generated rendering is the fallback, not the aspiration. It exists so the long tail is
  free; the screens the operator uses every day stay hand-made.
- The parent link on a thread is the smallest useful piece of this plan and can be done
  before the rest.

## Phases

### Phase 1: the parent link and the tree (small)

A parent thread id on the thread record, the sidebar nested, the status dot rolled up.
Nothing spawns children yet; hand-off already produces thread pairs that belong under one
another, and `stratta new --parent` is enough to test it.

### Phase 2: the palette (medium; after code mode Phase 0, the app-first plan's Phase 2, and slash commands Phase 3)

The app's and the viewer's palette over the command language, with forms from the
operations' argument schemas and confirmation driven by the read-only flag. The command bar
already accepts a typed line by this point; what this adds is discovery — the list, the
form, and the help — for the lines a person would not have known to type.

### Phase 3: what applies now (small)

An operation declares when it applies; the palette and the key handlers stop offering what
cannot be run. The viewer's existing "nothing to approve" cases move to this.

### Phase 4: skill cards (medium; needs [policy as actions](policy-as-actions.md) Phase 2)

A generic card from a skill's schema and state, with the policy skill as the first one,
and its edits going back through the skill's actions.

### Phase 5: pending effects (small to medium)

Described-but-not-yet-run effects as timeline items that can be approved or denied.

## Not in scope

- A replacement for the thread screen or the diff panel. Those stay hand-made.
- Rendering a state machine. Worth doing when a thread's lifecycle is declared as one;
  today it is not.
- Configuration screens for anything that is not a skill.

## Open questions

- Settled by the app-first plan rather than here: the shared definition lives in `core/`,
  as the parser and the operation specs, so neither front end holds the language and no
  module is shared between `gui/` and `tui/`.
- Is the generated form good enough for operations with nested arguments, or does the
  palette only offer the flat ones?

## Findings

*Empty until Phase 1 runs.*
