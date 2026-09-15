# Does the route index earn its context? — kill criteria and what we can actually measure

**Date:** 2026-09-14
**Status:** open, with one sub-claim settled
**Follow-up to:** PR #17 ("no evidence the index changes behaviour")

## The claim under test

`sync-agent-skills.sh` generates `.agents/AGENT_RULES.md`, imported into every consumer's always-loaded
context. The routes half pairs a trigger with the skill that owns the rule. Three justifications were
offered for it when the mechanism landed: **budget isolation**, **curated order**, and **cross-harness
portability**. None had been tested.

## Decompose first: this is three claims, not one

The question "does the index help?" is not one experiment. It separates cleanly, and two of the three
parts need no eval harness at all:

| Claim | Status | How settled |
|---|---|---|
| Budget isolation | **Falsified for Claude Code** | Direct measurement |
| Curated order | Untested | Needs an eval harness |
| Cross-harness portability | Structural, not empirical | A harness either has an import mechanism or it does not |

## The budget claim is falsified where it matters most

Claude Code preloads every skill's `name` + full `description` at startup (established in the prior-art
round behind #17; Anthropic's docs state a Skill has exactly one description field, loaded up front).
The descriptions are therefore in context **whether or not** the index exists — so the index does not
replace them, it adds to them.

Measured by `scripts/measure-index-overhead.sh`, at 11 vendored skills:

```
Native preload (name + description):     7266 bytes
Generated index total:                   1934 bytes
  of which standing rules:                185 bytes
  of which routes + scaffolding:          1749 bytes
→ routes are ADDITIVE: +26% on always-loaded context
```

**The routes section costs 26% more always-loaded context in Claude Code and returns nothing the harness
did not already have.** Budget isolation was the weakest of the three justifications and it is the one
that measured false. Committed as a script, not a number in prose, so it stays checkable as the hub grows.

> **Amended 2026-09-15 — the figures above are superseded; kept as the record of what was measured then.**
> Two corrections, neither of which rescues budget isolation:
> 1. **The measurement over-counted.** Claude Code strips block-level HTML comments before injection, so
>    the 235-byte provenance header likely never reaches context. Dropping the section blurb removed
>    another 82 bytes. Current figures: index 1852 bytes on disk, **1617 reaching context**, routes
>    **+22%**, not +26%.
> 2. **"Returns nothing the harness did not already have" does not follow.** That inference is retracted
>    in `2026-09-14-routing-index-prior-art.md`: verbatim restatement measurably improves model
>    performance, so redundancy is not self-evidently waste. The *budget* claim still measures false —
>    the routes are additive, not a saving — but the leap from "duplicate" to "worthless" was unsupported.

### The standing-rules half is unaffected

This finding does **not** touch the standing rules. No skill description carries them — they have no other
delivery channel — so they are not redundant with native preloading at any size. At 185 bytes they are
2.5% of the preload. The two sections have genuinely different warrants, which is an argument for the
split being right even though one half is now on notice.

## The naive A/B is not runnable in the primary harness

The obvious experiment — same tasks, index vs no index, measure whether the right skill loads — cannot be
run in Claude Code, because **the control arm is unreachable**: descriptions are preloaded natively and
there is no way to turn that off. Both arms would have the descriptions; only the redundant copy would
vary. That measures the value of duplication, not the value of routing.

This is worth stating plainly because it explains why the evidence was missing rather than merely
neglected. A real test needs a harness with no native skill preloading, where the index is the only
channel — which is also the only configuration in which the mechanism's remaining justification applies.

## Kill criteria — what retires the routes section

Retire it (keep standing rules) if **any** of:

1. **Overhead without benefit.** Routes exceed ~25% of native preload (they are at 26% now) *and* no
   measured selection improvement exists in a non-preloading harness. The first half is already true;
   only the second is outstanding.
2. **A/B null in a non-preloading harness.** Given a harness with no preloading and a task set where a
   specific skill should fire, the index arm does not beat the no-index arm on correct-skill selection.
3. **Native routing lands upstream.** A harness ships curated ordering or trigger-based routing as a
   first-class feature, making a hand-generated index redundant by construction.

Keep it if a non-preloading harness shows a real selection improvement, since that is the configuration
the mechanism is actually for.

## What would reopen the untested half

An eval harness in a non-preloading harness, with sample tasks whose correct skill is known in advance.
`MentalGear/agent-playbook-test` exists for this and is currently empty. Building it against Claude Code
would not answer the question, per the section above — so the harness choice is the first decision, not
the task set.

## Honest summary

One of three justifications is now measured and false in the primary harness. One is structural and needs
no experiment. One remains untested and needs a harness we do not yet have. The routes section is not
retired on this evidence, but it is no longer justified by budget, and that claim should stop being made.
