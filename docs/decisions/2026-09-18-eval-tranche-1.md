# First behavioural evidence: the shipped playbook vs no playbook

**Date:** 2026-09-18
**Status:** diagnostic complete; three actionable findings for the hub
**Harness and full results:** `MentalGear/agent-playbook-test` → `eval/RESULTS.md`
**Follows:** `2026-09-14-routing-index-prior-art.md`, `2026-09-15-phase-grouping-rejected.md`

## Why the question changed

The open question had been *"does the route index improve skill selection?"* That is the mechanism. The
higher rung, raised in review, is *"does the playbook change what the agent does at all?"* — the
existence question, which nothing had tested. If it does not move behaviour against no-skills, routing is
moot. So the first experiment is two arms, not three, and the metric is **behaviour**, not selection.

## Design

- **Harness:** headless `claude -p`, Sonnet, no extended thinking, in a fresh throwaway copy per run.
  The Agent-tool sub-agent route was probed first and rejected: a sub-agent inherits the parent's project
  root and cannot be pointed at another, so all arms would have been identical (documented in
  `sub-agents.md`; verified by a probe that saw no vendored skills and no `CLAUDE.md`).
- **Arms:** A0 = bare checkout; B = the shipped configuration (skills vendored, `CLAUDE.md` importing
  `AGENT_RULES.md`). The arms differ only by working directory.
- **Items:** 20, written from the user's situation with trigger words scrubbed, near-misses included,
  two negative controls where no skill applies. Each has ≥1 trace-observable check; scoring never asks the
  agent what it did.
- **Isolation:** verified — 0 of 38 runs touched the parent session, the hub, or the item bank.

## Result

| | B (playbook) | A0 (none) |
|---|---|---|
| Checks passed | **87.0%** | 77.8% |
| Items fully passing | **13/19** | 11/19 |
| Tool calls / wall time | +21% / +24% | — |

**Per item: B wins 3, loses 1, ties 15.** Sign test p ≈ 0.63 — not an inferential result and not
presented as one. The power analysis in the prior-art record predicted exactly this at n ≈ 20.

What makes the diagnostic informative is *which* items moved. The three wins are each the skill's
signature behaviour, and A0 did the reasonable local thing each time:

- **stuck-on-a-problem** — A0 patched the crashing function; B swept all five siblings and landed a test.
- **verification-instruments** — A0 ran the suite; B mutation-checked the fix in a worktree and called the
  test decorative.
- **project-gates** — A0 wrote CI; B wrote the gate manifest and ran it.

The one loss is an over-trigger with an identical outcome (below).

## Three findings the hub should act on

**1. `subagent-framework`'s trigger over-fires.** *"About to write real code"* fired on a one-line rename
(a negative control). The agent followed the route faithfully, loaded 17.5 KB, and the skill then told it
not to delegate. Cost with no benefit. The opener names an action almost every task involves; it needs to
name the *decision* — whether to delegate — not the act of writing code.

**2. The don't-reload line is ignored.** Two runs re-loaded a skill they already had (one loaded
`independent-expert-review` three times). The index says *"skip a route whose skill is already loaded this
task."* Either that guidance needs to be stronger, or it is the wrong channel for it — a rule about
loading behaviour sitting inside the thing being loaded.

**3. Some tasks have two right skills.** Of three routing misses, two were the agent loading a
*defensible* skill: `verification-instruments` for "is this actually done, should I trust it?";
`subagent-framework` for "add CSV export." The single-label assumption is the eval's, not the agent's —
MetaTool hit the same wall and merged tools until it held. Sharper triggers or accept-sets per item are
the two ways out.

Also observed, not a defect: **6 of 17 runs loaded more than one skill.** One task touched several. That
is the empirical form of the phase-grouping probe's finding that situations recur across skills.

## What the rubric could not see

On one tied item B re-ran a scratch benchmark that a design decision rested on and reported that **its
headline number does not reproduce.** No check captures that, and it is the most valuable single outcome
in the run. Trace-scoring has a ceiling; the judge-scored half of a fuller eval would be for exactly this.

## Evaluator error, reproduced in miniature

Five of my own rubric and fixture bugs were found only by reading the trace behind a surprising number —
including a contamination regex that excluded two clean runs, and a fixture whose task claimed a fix that
did not exist (**both arms noticed and refused**, correctly). The prior-art record cites an 18.5%
evaluator–human disagreement rate across published benchmarks; this run did not escape it. Every number
above was checked against its trace, and the item that could not be was removed rather than scored.

## What this does not settle

- Effect size in general (n = 19, one run).
- The **index vs the skills** — both are present in B. Separating them is the three-arm experiment
  (A2 descriptions-only / B / C placebo), now runnable in this harness.
- Behaviour with **extended thinking on**, which is what Claude Code ships. The prior-art record says
  the restatement benefit collapses there; the behaviour benefit measured here may or may not.

## Addendum — the delegation probe (same day)

Two tranche-1 items scored zero Agent calls under B: sf01 (build a feature) and ier01 (review panel) —
the two rules that require spawning agents. A six-run probe (Sonnet at 25 and 60 turns, Opus at 60; arm
B only) settled what that meant. Full table in the test repo's `RESULTS.md`.

- **The panel rule lands.** ier01's zero was single-run variance: the identical configuration spawned a
  panel on the repeat, and every probe run did (3, 3, 5 reviewers). Nothing to fix.
- **Delegate-by-default is followed — via its own exception.** No configuration delegated the build,
  and turn budget made no difference. But every model *engaged* the rule and invoked §1a in its own
  words — Sonnet: *"~100 lines… under the 'small stuff' exception… so I'll implement"*; Opus: *"§1a
  (small stuff) applies — I'm implementing."* Opus's Agent calls were reviewers, not implementers. The
  rule works as written; **§1a's "<~15 min / <~100 lines" is judged to cover a rate limiter with wiring
  and tests.** That is a threshold-calibration decision for the maintainer, and it means the eval's
  label ("non-trivial, should delegate") was the eval's judgment, not the skill's.
- **Cost scales with tier.** Opus loaded six skills on one build task and timed out at 600 s; 119 tool
  calls on the panel task. The stronger model reads the index more thoroughly and loads more.

**Finding 4, then:** decide whether "~100 lines" is the delegation threshold you want. If a ~100-line
feature with tests should be delegated, §1a needs a tighter bound or a different criterion — the models
are applying the one that is there.

## Decision

The playbook's content demonstrably changes behaviour in the prescribed direction on the tasks it is
written for. That is the first positive evidence the hub has had, and it is about the skills, not the
index. Next: fix finding 1 (cheap, clear), decide finding 2, and only then consider the three-arm
experiment — the mechanism question is worth less than it was, because the content question now has an
answer.
