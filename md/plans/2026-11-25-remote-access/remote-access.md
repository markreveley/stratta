---
type: plan
kind: exploration
---

# Remote access with authentication

> Status: proposed · 2026-11-27

## Summary

The README lists this as a next step. Today the app binds to `127.0.0.1` with no login and
the control socket is a Unix socket only its owner can open; both are deliberate, and both
mean the only honest way to reach Stratta from elsewhere is to forward a port over a
connection the operator already trusts.

This plan does the cheap, documented thing first, then adds authentication for the two
surfaces separately, because they can speak different transports and pretending otherwise
produces the worst of both.

## Why this exists

Kind: **exploration**, except Phase 0.

The README lists it as a next step. No use of Stratta has needed it yet. Phase 0, trying
the two forwarding paths, is cheap and settles what already works. The rest waits for a
second machine in real use.

## The two surfaces are not the same problem

- **The terminal client** can speak anything. It can hold a connection that needs no
  inbound port on the machine running the daemon and that authenticates both ends — a
  QUIC-based peer-to-peer transport such as Iroh, which Mjolnir already uses.
  This is the stronger position and the easier one: no listener is exposed, nothing is
  published, and the client already speaks a framed protocol over a socket.
- **The browser** cannot. The app needs a transport a browser speaks, which means a
  listener, a certificate, and a login. Everything expensive about this plan is on this
  side.

So: the client gets remote reach first and cheaply, and the app gets it second and
properly. That ordering also matches the earlier finding that the app's advantage is
reaching a phone or another laptop with nothing installed — which is exactly the case that
needs the login, so it cannot be skipped, only deferred.

## Design

- **Phase 0 is documentation**, not code: the port-forwarding recipe for the app and the
  socket-forwarding recipe for the client, in `docs/`, with what each one does and does not
  protect. Many operators need nothing else, and writing it down is what stops the next
  phases being built for the wrong reason.
- **The socket API over a transport.** `Stratta.API` is already the whole surface and the
  socket already frames it. A remote transport is a second listener onto the same API, with
  the caller identified by the transport rather than by the operating system.
- **What a remote caller may do is a grant**, from [delegated authority](../2026-11-25-delegated-authority/delegated-authority.md).
  Remote access without narrowing is a worse version of the local model, not an extension
  of it: the whole point is that a connection from a phone can be allowed to approve and
  not to ship.
- **The app's login** is a real login, not a shared secret, and it belongs to the operator's
  own identity system rather than to Stratta — which in practice means OpenID Connect for
  the flow and WebAuthn passkeys for the credential. Stratta's part is to accept an
  authenticated identity and map it to a grant, and to implement neither.
- Every remote answer is a [decision record](../2026-11-25-decision-records/decision-records.md) naming the transport it
  came in on. "Approved from the phone" should be a readable fact.

## Phases

### Phase 0: write down the forwarding recipes (small, documentation)

These are the two paths [the app first](../2026-11-25-gui-first/gui-first.md) names in its Design 8 as things that
should already work and have never been tried: the terminal client against a socket
forwarded with `ssh -L`, and the app through a forwarded port. Trying them is the content
of this phase, and the recipes are what comes out of it.

### Phase 1: the API over an authenticated transport, for the client (medium)

Needs Design 1 of the app-first plan first — everything the app does going through
`Stratta.API` — because a second listener onto the API is only worth having once the API is
the whole surface. That plan's Phase 5 then does the app's half of this with forwarded
sockets and a host list, which is the cheaper route and leaves this phase to the case
forwarding cannot reach: no inbound port, and surviving a change of network.

A second listener onto `Stratta.API`, caller identity from the transport, grants deciding
what is permitted, `stratta --remote`. No inbound port where the transport allows it.

### Phase 2: the app behind a login (medium to large)

An authenticated identity accepted by the app, mapped to a grant, with the binding and the
certificate story written down. The safety note in the README changes only when this is
done.

### Phase 3: notification where the operator is (small to medium)

A blocked thread is only useful remotely if the operator learns about it. What that is
depends on Phase 2 and on nothing in this repository today.

## Not in scope

- Several operators, teams or sharing a thread with somebody else.
- Hosting Stratta for anyone. Every phase here assumes the operator's own machine and the
  operator's own identity.
- Removing the loopback default. It stays the default after every phase.

## Open questions

- Does Phase 1 need its own transport at all, given that forwarding a Unix socket over an
  existing trusted connection already works? The case for it is no inbound port and
  surviving a change of network; the case against is that Phase 0 may be enough.
- Does the app's login gate the whole app, or the actions within it? Gating actions is the
  right answer and the more work.

## Findings

*Empty until Phase 0 is written.*
