# Grouping the route index by workflow phase — probed and rejected

**Date:** 2026-09-15
**Status:** closed — no change made; the flat list stands
**Follows:** `2026-09-14-routing-index-prior-art.md`

## The proposal

The routes section of `.agents/AGENT_RULES.md` is a flat list of one line per vendored skill. The order
follows the consumer's `SKILLS=(…)` declaration and is meant to read as a workflow, but nothing in the
output says so — a reader sees eleven equal bullets.

The proposal was to group routes under workflow-phase headings (*Before you build · While building ·
When it goes wrong · Before it lands · Closing out*), carried by a new `phase:` frontmatter field.

The motivating argument was the strongest one available: a harness that preloads skill descriptions
loads them as an **unordered set**, so sequence and grouping are the one thing the routes could carry
that is not a verbatim restatement of something already in context. It was the only part of the routes
section with a mechanism by which it could beat a length-matched placebo arm.

## The probe

Rather than build it and argue about the taxonomy afterwards, assign all 13 skills a phase and count
the failures. The criterion was fixed **before** assigning:

> A skill **breaks** if it genuinely fires at two or more phases, such that filing it under one would
> stop an agent in the other from considering it.

That is the operational harm. Grouping only helps by narrowing what gets considered, so a mislabel
does not merely look untidy — it hides the skill from the situation that should load it.

Evidence used: each skill's `description`, in particular the second "Also when …" sentence, which is
where additional firing moments are named.

## Result — 7 of 13 break

| Skill | Trigger phase(s) | Verdict |
|---|---|---|
| `end-of-round-report` | closing out | fits |
| `salvage-subagent-transcript` | when it goes wrong | fits |
| `stuck-on-a-problem` | when it goes wrong | fits |
| `subagent-framework` | while building | fits |
| `propose-skill` | hub contribution | fits, off-axis |
| `review-skill-proposal` | hub contribution | fits, off-axis |
| `agent-access` | while building + authoring a skill | **breaks** |
| `agent-repo-layout` | repo setup + building + closing | **breaks** |
| `project-gates` | setup + before it lands | **breaks** |
| `independent-expert-review` | design review + diff review | **breaks** |
| `verification-instruments` | filing a defect + trusting a result + guarding a fix | **breaks** |
| `solve-by-construction` | choosing designs + landing a guard + where a fix belongs | **breaks** |
| `agent-operating-principles` | design + tooling + debugging + spikes (7 habits) | **breaks worst** |

Three details make the count worse than 7/13:

1. **Two passes are an illusion.** `propose-skill` and `review-skill-proposal` fit only because
   "hub contribution" was invented as a bucket, and it is not a workflow phase. Restricted to the 11
   workflow skills, **4 fit cleanly**.
2. **`project-gates` names two phases in one sentence** — "setting up a repo's quality gates, *or*
   deciding which gates to run before a change lands." No labelling judgment resolves that; the skill
   has two genuine entry points.
3. **`agent-operating-principles` is unassignable.** Seven habits spanning research, tooling,
   debugging, testing and decision criteria. Any single label misstates it.

## Why this is a domain finding, not an implementation problem

These skills are **situation-triggered, and situations recur across phases.** A guard gets landed while
building, while fixing, and while reviewing — that is the nature of the rule, not a defect in how it
was written. A taxonomy that assumes one home per skill is describing a different domain than the one
we have.

The failure mode is also the wrong way round from the usual "nice-to-have didn't pay off". Grouping
would have **actively hidden** skills: filing `verification-instruments` under *Before it lands* means
an agent filing a defect — its literal first trigger words — never sees it. The mechanism meant to help
(narrowing the candidate set) is the mechanism that does the damage.

## Decision

**Keep the flat list.** Not by default or inertia, but because a skill with multiple entry points can
appear once in a flat list without being misrepresented, and grouping forces a single home on things
that do not have one.

This also closes the last open justification for the routes section. Recap of where the three stand:

| Justification | Status |
|---|---|
| Budget isolation | Falsified by measurement (`2026-09-14-routing-index-evidence.md`) |
| Non-redundant structure via phases | **Rejected here** — the taxonomy does not fit |
| Cross-harness portability | Stands; structural, not empirical |

The routes are retained on the third justification alone, plus the open possibility that verbatim
restatement itself helps (`2026-09-14-routing-index-prior-art.md`), which is unresolved and would need
a three-arm, ~200-item experiment to settle.

## What would reopen this

A different axis than workflow phase — one where skills genuinely have a single home. Grouping by
*object acted upon* (code / process / repo / the hub) is the obvious candidate and was not probed.
Anyone proposing it should run this same probe first: assign all skills, count the breaks, and publish
the count before writing any code.
