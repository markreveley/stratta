---
type: plan
kind: need
status: proposed
created: 2026-11-25
---

# Authority for an answer

## Summary

Today the authority to answer a permission request is "being able to open the control
socket". That is the whole model, and this repository already documents where it fails:
[pane threads](pane-threads-via-hooks.md) notes that any process running as the operator
can reach the socket, including a shell command an agent was allowed to run, so an agent
can approve a different pending request. The two mitigations proposed there — asking the
operating system who is on the other end of the socket, and a marker in the agent's
environment — are checks on who is calling. They are worth having and they are heuristics.

This plan makes the authority to answer a thing that is **held and presented** rather than
inferred from the caller, so that it can be narrowed, time-boxed, revoked and recorded. Its
first use is a view that can answer; [an agent as an approver](agent-approver.md) would be
a later one.

## Why this exists

Kind: **need** for Phases 0 and 1, **exploration** from Phase 2 on.

The fact: any process running as the operator can answer any request, including a shell
command an agent was allowed to run. It has not been seen to happen, and for one
operator attending their own agents the risk is modest. Views that can answer make it
less theoretical: [views as separate programs](composed-surfaces.md) Design 7.

From Phase 2 on this is exploration. The operator is interested in authority and
identity for agents and uses Stratta as the place to try them. That is a reason to build
it. It is not a claim that the coding tool needs it, and the plan should be read that
way.

## The order of work, and why it matters

Start with the cheap version and only pay for cryptography when a grant has to leave the
operator's own machine and trust boundary:

1. **An unforgeable local grant.** A secret in the data directory, mode 0600, that an
   answer must present. Closes the documented hole, needs no new dependency, and is worth
   doing on its own merits.
2. **Narrowing.** A grant that names what it may answer — these tools, this thread, this
   folder, until this time — and that can be handed down only as something strictly
   weaker. This is the part that makes delegation to anything other than the operator
   expressible.
3. **Signing.** An answer that carries who gave it, provable later, with the key held by
   the operator rather than by the daemon.
4. **Across machines.** Grants that are verifiable by a daemon that did not issue them.

Steps 2 to 4 want an attenuable capability token — Biscuit is the open specification for
exactly this, and is what IdentiKey's `identikey-capability` mints and verifies —
and a signature scheme over the answer (Ed25519 is enough; the same implementation offers a
post-quantum option beside it). **Stratta should depend
on neither.** It defines a verifier behaviour and ships the local implementation; an
external implementation is configured in, the way a provider is. This is kept as a rule
of the repository: see [design commitments](../docs/design-commitments.md), "Authority is
Stratta's; identity is configured in".

## Design

- `Stratta.Authority`: a behaviour with one question — may this grant answer this request
  this way? — and two implementations, local and external.
- Every answering path presents a grant: the app's session, the client's invocation, a rule
  in [policy](policy-as-actions.md), a reviewer thread. The caller checks from the
  pane-threads plan stay; a grant is a second line, not a replacement.
- The grant's id goes into the [decision record](decision-records.md). A decision with no
  grant is a bug once this lands, and the record is where that becomes visible.
- Issuing and revoking: `stratta grant` and `stratta revoke`, with `stratta grants`
  listing what is live. An operator who cannot see their outstanding grants does not have
  a permissions system.
- Narrowing on hand-down: a grant may only produce a weaker grant. Enforced in the
  behaviour, tested as a property.

## What this cannot do

Worth writing in the plan so it is not claimed later: a signature attests custody, not
truth. This machinery can establish that a particular holder, under a particular grant,
answered a particular request at a particular time. It cannot attest that an agent reasoned
honestly or that its claim was correct. What is being built is accountability, not
verification.

## Phases

### Phase 0: the hole, measured (small)

Reproduce it: a demo-agent thread running a shell command that calls `stratta approve` for
another thread's pending request. This is the test that the rest of the plan has to keep
passing in the negative, and it belongs in the suite whether or not the later phases run.

### Phase 1: the local grant (small to medium)

The behaviour, the local implementation, a grant on every answering path, the grant id in
the decision record, and Phase 0's reproduction now refused. `stratta grants`.

This is also the login that [the app first](gui-first.md) needs before it opens a shell in
a web page: its Design 7 describes a token created on first start, kept in the data
directory and readable only by the operator, which is this grant with a narrower job. Build
one, not two, and let the app's session hold a grant — the grant is the more useful of the
pair, because a session that can be checked against what it may do can also answer a
request.

### Phase 2: narrowing (medium)

Grants that name tools, thread, folder and expiry; hand-down that can only weaken;
`stratta grant --for`. Still local, still no new dependency.

### Phase 3: an external verifier (medium; needs a spike)

**Spike first:** how a Biscuit verifier implemented in Rust is reached from the BEAM — a native implemented function, a small long-running helper over a pipe the way
Harness already runs its process helper, or a port. The answer decides the shape, and the
helper route is the one the repository already has a precedent for. Record it in Findings
before building.

### Phase 4: signed answers (medium)

An answer carrying the operator's signature, the key held outside the daemon. Only
worthwhile once there is something to show the log to.

## Not in scope

- Authentication of a person. There is no login, and adding one belongs to
  [remote access](remote-access.md).
- Multiple operators, teams, or roles.
- Signing the agent's output or the claim sentences. Custody of a decision is the claim
  being made here; nothing more.

## Open questions

- Where does the root grant live: a file in the data directory, the operating system's
  keychain, or a hardware key store (TPM 2.0, or the platform's own secure element)? The
  first is enough for Phase 1 and the question only becomes real at Phase 4.
- Does the app hold a grant per browser session, and what happens when the browser is
  closed with requests outstanding?
- Does a grant survive a daemon restart? Pending requests do; the grants that may answer
  them probably must.

- IdentiKey's capability spec, version 1, binds a grant to one key and a hop cannot remove
  the binding (read 2026-11-23, not run). The local implementation is not bound by that.
  With IdentiKey as the external verifier, a view or a reviewer with a key of its own
  cannot be handed a bound grant, so narrowing would be enforced by what Stratta accepts
  and not by the token, until a later version of that spec.

## Findings

*To be filled in by Phase 0 and the Phase 3 spike.*
