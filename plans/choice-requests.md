---
type: plan
kind: exploration
status: proposed
created: 2026-11-26
---

# Pointing and choosing: structured turns between the operator and an agent

## Summary

Almost everything the operator and an agent say to each other is free text. One exchange
is not: a permission request. The agent asks, the daemon holds the question, the operator
answers `2a` with one of two values, and the thread goes on. This plan treats that
exchange as the first member of a family and adds two more:

- **Choosing.** A request whose answer is one of several options the request itself
  carries, not only approve or deny. The options can be drawn by a view, as text, as a
  list, or as pictures.
- **Pointing.** The operator selects a thing in a view (a file and line, a hunk of a diff,
  a region of a page, a claim) and it arrives in a thread as a structured reference, with
  no description typed.

Taken to its end, a whole exchange can be draw, choose, redraw: the agent presents a step
of a space the operator defined, the operator picks, and the agent presents the next. No
free text is needed on either side, and every turn is a recorded decision.

This is a design idea. Phase 0 finds out how much of it the agents already send, which
shapes the rest.

## Why this exists

Kind: **exploration**.

It came out of a conversation on 2026-11-26 about terminal-browser's element selection:
point at an element on a page and the agent in the next pane receives its description
and a picture. Nothing in the use of Stratta asked for it. Phase 0 costs only looking: what ACP permission requests and the agents' own question tools already
carry.

## What exists today

Checked in the code on 2026-11-26, at `412ac68`:

- A pending request is a timeline item of kind `approval` with a `request_id`, a `label`
  (`2a`) and a `status` of `pending`, then `approved` or `denied`
  (`core/lib/stratta/timeline.ex`).
- An answer is `:approve` or `:deny` and nothing else:
  `ThreadServer.handle_call({:approval, request_id, decision}, …) when decision in
  [:approve, :deny]`.
- A thread holding a request reports `blocked` with kind `permission`
  (`tui/lib/stratta/tui/status.ex`).
- Nothing carries a reference from a view into a thread. The composer takes text.
- Whether the agents Stratta runs offer more than two options on a request, or ask the
  operator questions through a tool of their own, has not been looked at here.

So the skeleton is there: a question that is held, named, shown in every front end,
answered once, and written to the timeline. What is fixed is its shape: one kind of
question, two answers.

## Design

### 1. A request has a kind and a list of options

- A request carries `kind` (`permission`, `choice`) and `options`: each an id, a label,
  and optionally a longer description and a reference to something a view can draw.
- A permission request is the case with the options `approve` and `deny`. Nothing about
  it changes for a front end that knows only that case.
- An answer names an option id. `stratta approve 2a` and `stratta deny 2a` stay;
  `stratta answer 2a <option>` is the general form.
- A request may allow a free-text answer beside its options. A request that does not is
  refused if the operator cannot answer it, and the operator can always dismiss a choice
  and type instead. Structure is offered, never a trap.

### 2. One record, one authority

- A choice writes the same [decision record](decision-records.md) as an approval: what
  was asked, the options, the one chosen, both times, and the evidence. There is one
  record type.
- A choice is answered under a grant like any other answer
  ([authority for an answer](delegated-authority.md)). A grant can then say which kinds
  it may answer, which is a narrowing that plan's Phase 2 already has room for.
- [Policy](policy-as-actions.md) can answer a choice by rule, and says which rule.

### 3. A view draws the options; the daemon does not

- The daemon holds the request and its options as data. How they look is a view's
  business: the viewer lists them, the dashboard shows the label, a graphical view draws
  them as pictures or as a layout.
- An option may refer to something drawable: a file, a diff, an image in the thread's
  folder, an address in the app. The reference is resolved by the view, with the same
  path checks the files work needs.
- This is where [views as separate programs](composed-surfaces.md) carries weight: a
  choice that is better seen than read is shown by a view opened for it, through the
  opener, and closed when it is answered.

### 4. A reference is a thing the operator can send

- A reference names a kind (`file`, `hunk`, `region`, `claim`, `thread`), a locator, and
  an optional excerpt or image.
- `thread.send` takes references beside text. A view sends one with
  `stratta point <thread> --file PATH:LINE` and its siblings, or through the socket.
- The agent receives it as text it can read, in a fixed form, with any image attached
  the way the agent's protocol allows. Stratta does not ask agents to learn a new
  message type.
- The timeline shows a reference as a reference, so it can be followed back.

### 5. A space the operator defines

The furthest form. The operator, or a skill, declares a space: the kinds of step, the
options each may offer, and what ends it. The agent's turn is to present the next step
inside that space; the operator's is to pick. What comes out is a path through the space,
each step a decision record.

- It is the same request and the same answer as Design 1. What is new is that the
  options of the next request depend on the answer to the last, and that a declared
  space says what a valid next request is.
- The daemon checks a presented step against the space and refuses one that falls
  outside it, the way the files work refuses a path outside the folder.
- This has the discipline of a decision model: the questions are fixed in advance and
  the model fills them in, not the other way round.

## Phases

### Phase 0: what the agents already send (small; needs nothing)

With the demo agent and with recorded sessions from real agents where they exist:

- what options a permission request carries beyond approve and deny, and what Stratta
  does with the others today;
- whether an agent asks the operator a question through a tool, and what that looks like
  in the timeline;
- whether an agent's protocol can carry an image or a file reference in a user message.

Write the answers into Findings, with fixtures. The outcome is one of: the agents already
send choices and Stratta flattens them; they send nothing of the kind and a choice has to
be raised some other way; or it differs by agent.

### Phase 1: an answer is an option (small to medium; needs step 3 of `next.md`)

`kind` and `options` on a request, `stratta answer`, the viewer and the dashboard listing
options, the decision record carrying them. Approve and deny unchanged. Tests: a demo
agent request with three options answered each way; an unknown option refused; a
front end that knows only two options still works.

### Phase 2: references (medium; needs step 8 of `next.md`)

The reference, `thread.send` taking it, `stratta point`, the fixed text form the agent
sees, and the timeline item. The first sender is the diff view, which can point at a
hunk.

### Phase 3: a view that draws a choice (medium; needs Phase 1 and step 16 of `next.md`)

One view, a page like the others in [views as separate programs](composed-surfaces.md),
that shows a request's options and sends back the one picked, opened by the opener when
a `choice` request arrives and the operator has asked for it.

### Phase 4: a declared space (a spike; needs Phase 3)

One small space, declared by hand, run end to end with no free text: for example, a
review of a diff as accept, reject or ask-about, hunk by hunk. A yes or no on whether it
is worth a format, with what was awkward.

## Not in scope

- A layout language. A view decides how options look.
- Replacing free text. The composer stays, and any choice can be dismissed for it.
- Teaching agents a new protocol. What an agent receives is text and, where its protocol
  allows, an attachment.

## Open questions

- Who raises a choice when the agent's protocol has no way to? A tool Stratta gives the
  agent, a rule, or a skill are the candidates. Phase 0 decides whether this matters.
- Does a surface hold a grant of its own, so that a view opened to show a choice can
  answer only that choice? This follows from the authority plan's narrowing and would
  make "which view may answer what" a thing the operator can see.
- Is a declared space a new format, or is it a skill's schema under another name?
  [Behaviour-shaped UI](behaviour-shaped-ui.md) Phase 4 draws a card from a skill's
  schema, which may be the same thing reached from the other side.

## Findings

None yet.
