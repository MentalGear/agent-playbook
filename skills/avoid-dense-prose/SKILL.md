---
name: avoid-dense-prose
description: Use whenever writing prose for a human to read — skill docs, PR/commit descriptions, review findings, delegation reports, or an ordinary chat response. Don't collapse several distinct concerns into one paragraph; give each concern its own paragraph or bullet so a reader can scan, address, and reply to them independently. Catches the dense-text anti-pattern where a claim, a caveat, an example, and a next step end up buried together in one block, none of them individually findable. Project-agnostic.
user-invocable: false
version: 1.0.0
---

# Avoid dense prose — one concern per paragraph or bullet

A paragraph that packs several distinct concerns together — a claim, a caveat, an example, and a
next step, say — reads as *one* idea and gets treated as one: a reader who agrees with the claim
silently inherits the caveat without noticing it, or replies to the first sentence and drops the
rest. Density isn't concision. Concision keeps one idea tight; density hides several ideas inside
one block so none of them is individually visible.

**The tell:** if summarizing a paragraph needs "also," "additionally," "however," or a hard topic
shift partway through, it's carrying more than one concern. Split it — a new paragraph, or a bullet
list — so each concern is independently scannable and independently answerable.

**What doesn't need splitting:** a paragraph that elaborates a *single* claim — evidence for it, a
worked example of it, a qualification of that same point — isn't dense, it's just doing its one job
at some length. The test: could a reader excerpt a sentence from the middle and lose nothing about
the paragraph's *other* concerns? If yes, there's only one concern. If the excerpted sentence turns
out to gate, contradict, or redirect the sentences around it, that's usually two.

**Applies wherever prose reaches a reader** — skill docs, PR/commit descriptions, review findings,
delegation reports, and ordinary chat replies. It isn't scoped to any one artifact.

> This is the general form of a rule **end-of-round-report** already states for its own narrow
> case ("every list of changes, statuses, or artifacts... must render as a `-` list, never as a
> paragraph packing multiple facts into one block of prose"). That skill owns the report-specific
> application; this skill owns the general rule everything else follows.
