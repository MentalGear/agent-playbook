# Deferred: forced-choice routing, and sub-agent bidirectional messaging

**Date:** 2026-09-13
**Status:** deferred — not rejected on principle; deferred for lack of evidence and, in one case, for a
harness dependency the hub cannot specify.
**Context:** proposed while building the routing index (`.agents/AGENT_RULES.md`, PR #17) and the
sub-agent configuration rules (`subagent-framework` §2/§3/§4).

Recorded per **agent-operating-principles** §1 — *negatives are first-class results*. Both ideas are
plausible and may well be right; the point of this file is that re-proposing either should cost a
maintainer nothing to evaluate, and should require new evidence rather than a repeat of the argument.

---

## 1. Forced-choice intro on the routing index

**The proposal.** Prefix the generated routing index with an instruction along the lines of: *you must
select at least one route; if several fit, weight them by percentage; a "none" option exists but requires
a well-reasoned paragraph justifying it.* Restate the demand after the list. The stated rationale was to
make **not** choosing more expensive than choosing.

**The concern behind it is real and remains open.** The failure mode — an agent reads the index and routes
nowhere, silently — is plausible and currently **unmeasured**. Nothing here disputes that.

**Why deferred:**

- **It penalizes the common case.** Most turns match no route at all ("what's the status", "show me that
  file", "yes, proceed"). Under this design the correct answer on those turns is the *expensive* one. The
  cost lands on the majority of turns to catch a minority failure.

- **Forcing a choice manufactures wrong routing, and wrong routing is worse than none.** Prior-art research
  conducted for this design (2026-08) found near-duplicate and overlapping triggers to be the most-cited
  cause of wrong-tool selection in agent systems. Making "none" costly does not improve matching; it
  produces *a* match. A skill loaded for a task it was not written for then applies its rules to that task.
  Silence is recoverable; a confident wrong route is not.

- **Percentage weights are false precision.** Nothing consumes them, nothing calibrates them, and there is
  no way to establish that 70/30 beats 60/40. Compare **verification-instruments** §5: a number whose
  instrument does not exist is an assertion wearing evidence's clothing.

- **It reopens a door closed by construction.** The routing index deliberately carries *no* behavioural
  rules — the generator owns the whole line so that a rule cannot reach always-loaded context. A mandatory
  selection procedure in the file's preamble is exactly such a rule, reintroduced by hand.

**The salvageable core.** The asymmetric-cost instinct is sound but inverted. The version that survives the
objections is *cheap to decline, costly to decline a clear match*: no justification when nothing fits, a
named reason required when a trigger plainly matched and was not taken.

**What would reopen this:** a measured skip rate. If instrumentation shows the agent passing over routes
whose triggers clearly matched, build the inverted form above — not the original. Absent that measurement,
this is a forcing function for a failure that has not been observed.

---

## 2. Sub-agent bidirectional messaging (callback channel)

**The proposal.** A communication channel between orchestrator and sub-agent: questions flowing upward from
a blocked agent, and progress requests or revised instructions flowing downward mid-run.

**The two directions have different verdicts.**

### Upward — an agent asks a question mid-run

- **It fights the compression that makes delegation worth doing.** §0.5 (*spec in, distilled result out*)
  exists because a sub-agent's value is that it returns a summary, not a conversation. A live question
  channel turns a delegation into an interactive session and floods the orchestrator's context — the
  context-flood anti-pattern the skill names explicitly.

- **It removes pressure that currently does useful work.** §1b already treats a worker that stalls on
  ambiguity as evidence of an under-specified brief — *an orchestrator bug*. Making questions cheap makes
  writing a vague brief cheap too, and the brief is where the leverage is.

- **The capability already exists with a round-trip.** §3.10 requires an agent to *stop and report the
  ambiguity* rather than guess; the orchestrator re-scopes and re-delegates. That is a question channel
  whose latency is one round — and the round-trip is precisely what keeps the pressure on the spec.

### Downward — revised instructions mid-run

Argued against outright. Changing a brief mid-flight yields a deliverable built half under spec A and half
under spec B, with no record of the seam — very hard to verify, and it undercuts the main loop's
gate-observation duty (§0.1). *Stop, re-scope, re-delegate* is auditable and barely slower. Progress
reports flowing upward are a different thing and are already required by §3.9.

### The blocking issue for both directions

**It is harness-dependent in a way the hub cannot specify.** Whether a running agent can be messaged at all
varies by harness, and many cannot do it. A skill assuming that capability would be unimplementable for
most consumers, violating the parameterized/project-agnostic bar in **propose-skill**. The *contract* — what
an agent does when blocked — is general and belongs in the skill; the *transport* is not the hub's to
define.

**What would reopen this:** evidence that stop-and-re-delegate is materially more expensive than a live
question for a real class of task, **plus** a transport that can be expressed as a host-supplied slot rather
than a hardcoded assumption.

---

## Common thread

Both proposals place an **unmeasured behavioural bet on the always-loaded surface or the delegation
contract** — the two most expensive places in this method to be wrong, because a mistake there is paid on
every turn or every delegation, by every consuming repo. Neither is refuted. Both are waiting on the same
thing: a measurement that shows the failure they address actually occurs.
