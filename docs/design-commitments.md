# Design commitments

Rules this repository keeps across its plans. A plan that needs to break one says so and
says why. Each has the date it was decided and who decided it.

## 1. Plans define behaviours and name no product

Decided by the operator, 2026-11-24.

Nothing in Stratta names a terminal, a browser, a toolkit or any other product it could
be used with. A plan describes the behaviour it needs ("a host terminal that reads status
reports", "a browser that draws in a terminal pane") and leaves the choice of product to
whoever runs it. The operator's analysis of specific products is kept outside this
repository.

Named already, because Stratta is built on them or exists to run them: Jido, and the
coding agents Stratta runs.

**Exception: providers of environments.** Decided by the operator, 2026-11-26. A provider
of sandboxes or virtual machines for a thread to run in may be named, Mjolnir first. The
reason for the rule is that Stratta should not be shaped around one product in the space
it works in. An environment provider is outside that space: it supplies a place to run,
behind a behaviour, and naming it shapes nothing in the control plane.

## 2. Authority is Stratta's; identity is configured in

Decided by the operator, 2026-11-26. The design is in
[authority for an answer](../plans/delegated-authority.md).

- **Stratta owns grants.** What a holder may answer, how a grant is narrowed, where it is
  checked and how it is recorded are Stratta's own, and work with nothing but a local
  secret. A daemon with no identity layer configured is complete, not degraded.
- **Stratta does not own identity.** Who a holder is, how that is proved, and how an
  answer is signed so that it can be shown to someone else later belong to an identity
  layer outside this repository. Stratta defines one verifier behaviour and ships the
  local implementation. Any other is configured in, the way an agent provider is.
- **No identity layer is named or depended on.** Stratta takes no dependency on a token
  format, a signature scheme or a key store. The first external implementation is a test
  of the behaviour, not a commitment to that implementation.
- **The line between them.** A grant answers "may this be done". Identity answers "who
  did it, provably". Stratta needs the first to work at all, and the second only when an
  answer has to be believed by a daemon that did not issue the grant, or by a person
  reading the record afterwards.

What this rules out: a login built into Stratta; a grant that is only valid when an
identity layer is present; a record format that only one identity layer can sign.
