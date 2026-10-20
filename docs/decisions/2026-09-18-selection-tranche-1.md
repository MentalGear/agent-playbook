# Skill selection measured: precise everywhere except one trigger

**Date:** 2026-09-18
**Status:** measured; one trigger change proposed, with a prediction to check it against
**Harness and full tables:** `MentalGear/agent-playbook-test` → `eval/RESULTS.md`, "Selection tranche"
**Follows:** `2026-09-18-eval-tranche-1.md`

## The question

Tranche 1 measured behaviour. This measures the step before it: given a situation, does the agent load
the skill written for it — and only that skill? Selection is decided in the first one to three tool
calls, so this runs at a 5-turn budget and ~10 seconds per item, cheap enough to re-run after every
trigger change.

## Design

Built the way `skill-creator`'s trigger evals are built: two should-load items per vendored skill, ten
**near-misses** whose wording invites a named decoy skill but whose correct answer is another skill or
none, and four no-skill controls. 36 items × 3 rounds. Scored purely on the set of skills loaded.

## Result

| | |
|---|---|
| Expected skill loaded | **90%** (70/78) |
| Runs loading an extra skill | 11% |
| Near-miss decoy loaded | 13% |
| Spurious load on a no-skill task | 13% — **controls 0%** |

**Of 15 extra loads, 10 are `subagent-framework`. All 8 decoy and spurious loads are `subagent-framework`
on a trivial edit** — a variable rename (3/3 rounds), a missing semicolon (1/3). The other six decoys
fired zero times. Every skill routes precisely except this one.

The eight recall misses are not wrong loads. Six are a **substitute path**: when the repo already holds
the artefact a skill defines (`gates.yaml`, `access.yaml`), the agent reads the artefact instead of the
skill. That is defensible — the skill's job is the schema — and the single-label assumption scored it as
a miss. Two are round variance on ambiguous near-misses.

## Decision: change one trigger

`subagent-framework`'s opener names an *act* nearly every task involves:

> Use when about to write real code, or spawning a subagent.

It should name the *decision*:

> Use when deciding whether to delegate a piece of work, or spawning a subagent.

The derived route becomes *"deciding whether to delegate a piece of work, or spawning a subagent."*
Because the route is derived from this sentence, both channels change together with no drift.

**Prediction, stated before the re-run:** on the same 36 items, extra loads fall from 15 toward ~5 and
spurious loads from 4 toward 0; recall stays ≥ 90%; nm-9 ("one helper or two?") keeps loading it 3/3.
If the re-run does not show that, the change is wrong and gets reverted — the instrument exists to
make that call cheap.

## Caveats

- 5 turns measures *immediate* selection; extras and re-loads are lower bounds.
- 3 rounds: 3/3 and 0/3 are stable, 2/3 is variance.
- Sonnet without extended thinking. Tier changes loading behaviour — Opus loaded six skills on one task
  in the delegation probe — so this is one point, not a curve.

## Also observed

`subagent-framework` is 17.5 KB, the largest skill in the hub, and the one that over-fires. A wrong
load costs the whole file. Independently of the trigger, moving more of its body into `reference.md`
would cut the cost of every spurious load — worth doing, not done here.

## Result — 2026-10-20: the prediction held, p = 3×10⁻⁵

The change shipped as `subagent-framework` 1.4.0 (`129dd89`): only the description's first sentence,
body untouched, so the trigger is the sole variable.

**The month-old baseline could not serve as the control.** Between the two runs the CLI moved
2.1.277 → 2.1.304 and the `sonnet` alias now serves `claude-sonnet-5-5`; the baseline's model ID was
never recorded. So both arms were re-run **concurrently** — same model, same CLI, interleaved by round,
the old vendoring from a second checkout. The month-old run is kept only to show the drift.

| | month-old baseline | before (now) | after (now) | predicted |
|---|---|---|---|---|
| Extra loads | 15 | 19 | **5** | ~5 |
| Spurious loads | 4/30 | 6/30 | **0/30** | 0 |
| Decoy loads | 4/30 | 6/30 | **0/30** | — |
| Recall | 90% | 94% | **99%** | ≥ 90% |
| Re-loads | 2 | 5 | **0** | — |
| nm-9 (a real delegation decision) | 3/3 | 3/3 | **3/3** | 3/3 |

The drift is real: under the newer model the *old* trigger over-fired more (15 → 19). A before/after
against the stale baseline would still have pointed the right way, but would have mis-sized the effect.

**Paired by item × round:** `subagent-framework` over-loads were fixed in 16 runs and introduced in 0 —
exact sign test **p = 3×10⁻⁵**. Any extra load: 16 fixed, 1 introduced, **p = 0.0003**. This is the
first inferential result this harness has produced, and it was possible because the effect is
concentrated in one skill rather than diluted across all of them.

**Recall improved as a side effect.** aop-2 went 1/3 → 3/3 and nm-5 0/3 → 2/3: the right skill had
been pre-empted by `subagent-framework` loading first.

**What remains.** Of the 5 extras, 3 are aa-1 — "send a helper to rewrite `slug()`; it must never touch
`config/`" — which now loads `agent-access` **and** `subagent-framework` every round. That task is both a
delegation decision and an access-scope one; two skills is the correct answer and the single-label
rubric counts it as an extra. A month ago the same item loaded only `subagent-framework` and missed
`agent-access` entirely. The other two are single-round variance.

**Decision:** keep 1.4.0. The instrument did what it was built for — a trigger change, a prediction on
record, and a cheap re-run that could have reverted it.
