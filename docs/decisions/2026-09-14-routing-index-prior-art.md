# Prior art on evaluating a routing index — and why our first design was invalid

**Date:** 2026-09-14
**Status:** research complete; eval not built
**Supersedes reasoning in:** `2026-09-14-routing-index-evidence.md` (the "pure duplication" argument below)

## Why this exists

`2026-09-14-routing-index-evidence.md` measured the routes section at +24-26% of the native
description preload and argued that, since each route line is a *verbatim substring* of a description
already in context, it carries nothing. This document records the literature survey that followed —
beat 3 of the loop in **solve-by-construction** — and it **contradicts that argument.**

## Finding 1 — redundancy alone improves performance, so "it's a duplicate" is not a verdict

[Prompt Repetition Improves Non-Reasoning LLMs](https://arxiv.org/abs/2512.14982) (Leviathan et al.,
Google Research) duplicated prompts verbatim — `<QUERY>` → `<QUERY><QUERY>`, no new information at
all — and reported **47 wins, 0 losses** (McNemar, p<0.1) across Gemini 2.0 Flash/Lite, GPT-4o/4o-mini,
Claude 3 Haiku / 3.7 Sonnet, and DeepSeek V3. One custom retrieval task moved 21.33% → 97.33%.

The mechanism matters for us: causal attention means early tokens cannot attend to later ones, so a
second copy makes encoding effectively bidirectional. Restating something already in context is not
inherently wasted.

Two qualifications decide whether it applies here:

- **With reasoning enabled the effect collapses** — 5 wins, 1 loss, 22 neutral. The model already
  re-attends. Claude Code ships with extended thinking, which is the configuration that counts.
- **Gains were largest when the first pass placed the relevant material late.** Redundancy rescued bad
  positioning. See also [Lost in the Middle](https://arxiv.org/abs/2307.03172) (Liu et al., TACL) for
  the U-shaped primacy/recency curve — our index sits at a different prompt position than the
  auto-preloaded descriptions, so position is a live confound, not a neutral detail.

**Consequence:** the routes section may be doing real work or none, depending on configuration. What we
can no longer claim is that it is inert *because* it duplicates. That inference was wrong.

## Finding 2 — a two-arm A/B cannot answer the question

Because restating helps on its own, an index-present vs index-absent comparison confounds "does this
information help?" with "does restating anything help?"

The established control is a **length-matched placebo**
([arXiv:2601.22025](https://arxiv.org/html/2601.22025v1)): task-irrelevant content with the same
injection wrapper, organisation, and token length within 1%. Three arms, not two:

| Arm | Content |
|---|---|
| **A** | no index |
| **B** | the real index |
| **C** | placebo — same line count, position and syntax, but mismatched trigger→skill pairings |

`B − C` isolates whether the information helps. `C − A` measures whether restating anything helps.
Given Finding 1, **expect C to beat A** — and without C that gain would be misread as B's.

No published work runs this control for tool or skill selection; the technique is general
experimental design borrowed from elsewhere.

## Finding 3 — a 40-60 item eval is underpowered, and more runs per item will not save it

Exact conditional McNemar, α=.05 two-sided:

| n items | net effect | power |
|---|---|---|
| 40 | +10pp | **17%** |
| 60 | +10pp | **31%** |
| 60 | +15pp | 58% |
| 100 | +10pp | 54% |
| 200 | +10pp | 88% |

A +10pp net improvement — large for a prompt tweak — is detected **31% of the time at n=60.** The
likely outcome of building the eval we were planning is a real improvement reported as "no significant
difference."

And repeats do not fix it: 1 → 10 runs per item moves power only 30% → 40%, because variance is
dominated by **between-item** heterogeneity (which items are movable at all), not within-item sampling
noise. Three runs per item is about the right stopping point.

For scale of harness noise: the validity audit
([arXiv:2607.02577](https://arxiv.org/abs/2607.02577)) found **23 repeated runs of an identical
LiveMCPBench setup scoring 57.9%–76.8% — an 18.9-point spread**, enough to reorder a leaderboard. It
also found an **18.5% evaluator–human misalignment rate** across 496 expert-reviewed tasks.

## Finding 4 — dataset construction, and the leakage trap

[MetaTool](https://arxiv.org/abs/2310.03128) (ICLR'24) is the closest analogue: it measures tool-usage
awareness plus which-tool selection. Two things it did that we would have to copy:

- It **collapsed 390 tools → 195** by clustering description embeddings, expressly so each query had
  exactly one ground-truth label. There is **no established multi-label metric** for tool selection —
  the honest alternative is an accept-set per item, reporting how many items needed one.
- During human review it **removed queries containing tool names**, so the eval could not be
  self-fulfilling. It also found selection accuracy **rises monotonically with description length**,
  which makes description text a strong lever and a validity hazard at once.

Anthropic's own `skill-creator` is the most transferable recipe: **20 trigger queries (8-10
should-trigger, 8-10 should-not)**, **near-misses are the most valuable negatives**, 3 runs per query
with a 0.5 threshold, and a **60/40 stratified split** so the wording is not tuned to the task set. Two
limits: it tests **one skill in isolation**, so it measures trigger/no-trigger rather than
discrimination among competitors, and it counts any non-`Skill`/`Read` first action as a non-trigger.

Also worth reporting chance-corrected: with 13 skills, random selection is 7.7%
([Bits-over-Random](https://arxiv.org/pdf/2605.24660)), and raw accuracy inflates as the candidate set
narrows — which an index may itself cause.

## Decision

**Do not cut the routes section on the "it is duplication" argument.** That argument does not survive
Finding 1.

**Do not build a 50-item A/B.** At 31% power it would be theatre, and a null result would be
uninformative either way.

If we want an answer, two honest options:

1. **A ~50-item diagnostic** — report per-item paired outcomes and a confusion matrix over the skills
   to find *which* skills get mis-selected and why. No p-value, no claim of significance.
2. **A powered experiment** — three arms, ~200 items, or pre-screen a pilot to discard items both arms
   always get right and concentrate on contested ones, reported as a stratified estimate.

Either way, test in the configuration we ship (extended thinking on), interleave arms in time rather
than batching them, and fix model version and sampling settings.

**Where the literature does not cover us:** no published work evaluates a redundant routing index in a
runtime that already preloads the full skill list. Progressive-disclosure work (MCP tool search,
Claude Code's ToolSearch) addresses the opposite problem — removing definitions to save tokens — and
reports token savings, not selection accuracy. Doing this would be new work, which argues for building
it and for sizing it honestly.

## Sources

[MetaTool](https://arxiv.org/abs/2310.03128) ·
[BFCL v4](https://gorilla.cs.berkeley.edu/leaderboard.html) ·
[Gorilla](https://arxiv.org/pdf/2305.15334) ·
[ToolLLM](https://arxiv.org/pdf/2307.16789) ·
[API-Bank](https://aclanthology.org/2023.emnlp-main.187/) ·
[τ²-bench](https://github.com/sierra-research/tau2-bench) ·
[Validity Audit](https://arxiv.org/abs/2607.02577) ·
[Bits-over-Random](https://arxiv.org/pdf/2605.24660) ·
[Prompt Repetition](https://arxiv.org/abs/2512.14982) ·
[RE2](https://arxiv.org/abs/2309.06275) ·
[Lost in the Middle](https://arxiv.org/abs/2307.03172) ·
[Length-Control placebo](https://arxiv.org/html/2601.22025v1) ·
[BEIR](https://arxiv.org/pdf/2104.08663) ·
[skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
