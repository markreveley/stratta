# Design commitments

Rules this repository keeps across its plans. A plan that needs to break one says so and
says why.

## 1. The code stays neutral; plans and documents name what they mean

Stratta's code does not detect, depend on or special-case a product it could be used
with. It emits a status report and does not ask which terminal is reading it. It runs the
operator's opener and does not know what makes the splits. It defines a behaviour for a
thread's environment and for an identity layer, and ships a local implementation of each.

Plans and documents are different. They name the terminal, the browser, the toolkit, the
environment provider or the identity layer they have in mind, because a reader cannot
judge a design described as "a browser that draws in a terminal pane". A name in a plan
is a reference, not a dependency.

Built on, and so named everywhere: Jido, and the coding agents Stratta runs.

## 2. Authority is Stratta's; identity is configured in

The design is in [authority for an answer](../plans/delegated-authority.md).

- **Stratta owns grants.** What a holder may answer, how a grant is narrowed, where it is
  checked and how it is recorded are Stratta's own, and work with nothing but a local
  secret. A daemon with no identity layer configured is complete, not degraded.
- **Stratta does not own identity.** Who a holder is, how that is proved, and how an
  answer is signed so that it can be shown to someone else later belong to an identity
  layer outside this repository. Stratta defines one verifier behaviour and ships the
  local implementation. Any other is configured in, the way an agent provider is.
- **No identity layer is depended on.** Stratta takes no dependency on a token format, a
  signature scheme or a key store. The first external implementation is a test of the
  behaviour, not a commitment to that implementation.
- **The line between them.** A grant answers "may this be done". Identity answers "who
  did it, provably". Stratta needs the first to work at all, and the second only when an
  answer has to be believed by a daemon that did not issue the grant, or by a person
  reading the record afterwards.

What this rules out: a login built into Stratta; a grant that is only valid when an
identity layer is present; a record format that only one identity layer can sign.

## 3. A plan says what kind of thing it is

Every plan has a `kind` and a section, *Why this exists*, that gives the evidence.

- **need**: something observed in use, or a fact in the code, that is wrong or missing.
  The section says which, and whether it has actually been met in use.
- **experiment**: a question with a gate. It is built to be answered either way and may
  end in "no".
- **exploration**: built because the operator wants to try an idea, with Stratta as the
  place to try it. That is a good reason to build something. It is not a claim that the
  tool needs it.

The labels exist because the plans had run ahead of use: by 2026-11-26 there were
nineteen plans and no reported day of work with a real agent, and several plans
described an exploration as a need. A label describes; it does not rank. An exploration
the operator finds promising is worth doing for that reason. When use produces evidence,
the kind changes and the section says what changed it.

## 4. Plans propose; the operator decides

Most plans here were drafted by agents. A threshold, a stopping rule, an order or a
"should not" in a plan is the drafting agent's suggestion at the time it was written,
often on little evidence. It is not a decision, and a later agent should not treat it as
one. Whether to stop, continue, reorder or drop something is the operator's call, made
when there is something to look at. An agent that finds a plan's limit in its way says
so and asks; it neither enforces the limit nor ignores it.

The exceptions are the commitments in this file and what the operator has decided, which
`next.md` records with a date.
