---
type: plan
kind: need
status: proposed
created: 2026-11-25
---

# Traces and decision measures

## Summary

Once a thread's events and its [decision records](decision-records.md) exist, a thread is
already shaped like a trace: the thread is the whole, a turn is a span inside it, a tool
call is a span inside that, and a decision is a span with a known start, a known end and a
known answerer. This plan exports that shape as OpenTelemetry traces over OTLP and derives
a small set of measures from it.

The point is to spend no UI budget on dashboards. Export the trace and the operator's own
tooling draws it. What Stratta adds is not a chart, it is the one thing general
agent-watching tools cannot produce: spans for *decisions*, not just for model calls.

## Why this exists

Kind: **need** for one measure, **exploration** for the rest.

Waiting time per request, split into the agent's part and the operator's, is the
useful number: one piece of evidence on what answering requests costs. Exporting traces over
OTLP and the other measures are exploration.

## Why these measures

Five, chosen because each one is actionable and none of them is a token count:

- **Waiting time** — a decision's two times, split into the agent's part and the human's
  part. Expect the human's part to dominate and to be the thing worth fixing.
- **Rework** — a decision reversed, or an edit undone by a later edit in the same thread.
  A quality signal per agent, per model, per repository.
- **Cost to a decision** — tokens and tool calls spent in the turn that produced a
  request, rather than per session. "This approval cost 180k tokens to reach" is a number
  someone can act on.
- **Automatic share** — once rules exist, what fraction of requests never reached a human,
  and of those, how many were later reversed. This is the only honest measure of whether
  automating approvals helped.
- **Grounding** — of the evidence attached to a decision, how much the agent's own
  statement actually refers to. A cheap first proxy for whether the context was useful,
  and the hook that [context as a query](context-queries.md) builds on.

## Design

- One span per thread, turn, tool call and decision, with the thread id and slot name as
  attributes, and decision records linked by id.
- The OpenTelemetry Erlang and Elixir libraries, with the exporter switched off by default
  and configured by the standard `OTEL_*` environment variables, pointed anywhere the
  operator likes. Nothing is sent anywhere unless it is configured.
- Span and attribute names follow the OpenTelemetry semantic conventions where they apply.
  The GenAI conventions cover model calls and have nothing for a decision, so the decision
  span's attributes are Stratta's own and are written down in this plan as they settle.
- The measures above derived in the daemon and read through `measures.get`, so
  `stratta watch` and the app can show the two or three that belong on a dashboard
  (waiting time, automatic share) without an external tool being involved.
- Redaction before export: Harness already has a redaction module; prompts and file
  contents do not leave the machine, and the default is attributes that are structural
  rather than textual.

## Phases

### Phase 1: spans (small)

Threads, turns and tool calls as spans, exporter off by default, one test that asserts the
span tree of a demo-agent thread.

### Phase 2: decision spans and the two times (small)

The decision span, its answerer, and waiting time split. `measures.get` with waiting time
only.

### Phase 3: the rest of the measures (medium)

Rework, cost to a decision, automatic share, grounding. Each one needs a definition tight
enough to test; write the definition into this plan as it is settled.

### Phase 4: where they show (small)

Waiting time and automatic share on the dashboard and in the app.

## Not in scope

- Any chart drawn by Stratta beyond a number on an existing screen.
- Storing traces. Export, or derive a measure and keep the measure; do not become a trace
  store.
- Measuring model quality. These are measures of the control plane, not of the agent.

## Open questions

- Is grounding measurable without a model judging it? If not, it moves to the context
  plan, where a model in the loop is already assumed.

## Findings

*Empty until Phase 1 runs.*
