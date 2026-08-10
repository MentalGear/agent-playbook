---
name: salvage-subagent-transcript
description: Use when a delegated subagent goes stale (no progress for a long stretch), crashes or dies on a terminal error, gets interrupted, or returns output too thin or garbled to use. How to recover the work before relaunching anything — read the transcript for decisions rather than narration, inspect the workspace it left behind, then choose resume / harvest / discard, and re-scope the contract if the failure was yours. Prevents the default failure mode of spawning a fresh agent over a half-finished one and losing (or clobbering) its partial work.
user-invocable: false
version: 1.0.0
requires: [subagent-framework]
---

# Salvage a stale or crashed subagent

A delegation that died is **not** a delegation that produced nothing. The transcript, the diff on disk, and
the dead end it proved are all work you already paid for. Salvage first; decide what to relaunch second.

> **The reflex this exists to stop:** spawning a fresh agent on the same task. A new agent starts blind, redoes
> the discovery, and — if the dead one wrote to a shared tree — may clobber its half-finished work with a
> conflicting version of the same edit.

## 1. Classify what happened (it changes the salvage)
- **Stale** — still nominally alive, no progress for a long stretch. Its workspace is *live*; don't write to
  it concurrently. Stop it explicitly before harvesting.
- **Crashed / terminal error** — died mid-task. Workspace is frozen wherever it got to; safe to read.
- **Interrupted** — you or the harness stopped it. Same as crashed, but the last action may be half-applied.
- **Returned unusable** — finished and reported, but the output is too thin, garbled, or off-spec to act on.
  The transcript is intact and is usually the richest of the four.

You often can't tell "stale" from "dead" without progress checkpoints — which is exactly why long
delegations must emit them (**subagent-framework** §3).

## 2. Harvest, in this order

1. **The workspace diff first — it's the highest-value artifact.** In its worktree/branch/clone: `git
   status` and `git diff` (plus untracked files). Partial work is frequently 80% done and finishable in
   minutes. Do this before reading anything, because it tells you what the transcript needs to explain.
2. **The transcript for decisions, not narration.** Skim for: what it *concluded* (the API it picked, the
   root cause it found), what it *ruled out* and why, and where it got stuck. **Don't read the whole
   transcript into your context** — that's the context-flood anti-pattern; extract the findings and stop.
3. **What it proved doesn't work.** A dead end is a real result — an approach that failed for a cited reason
   saves the next attempt from repeating it. Record it (**agent-operating-principles** §1, negatives as
   first-class), or you'll re-delegate straight back into it.
4. **The failure itself.** The last error, the last gate output, the point of divergence.

## 3. Choose one: resume, harvest, or discard

- **Resume** — relaunch *that* agent from its transcript ("continue this agent"), never a fresh one. Right
  when it was making progress and hit something transient (a flaky gate, a timeout, a rate limit).
- **Harvest** — take the diff, finish it yourself in the main loop. Right when the work is nearly complete,
  or when the failure showed the task wasn't delegatable in the first place. This is the §1b main-loop
  takeover in **subagent-framework**.
- **Discard** — remove the workspace (`git worktree remove --force`), keep only the findings. Right when the
  diff is incoherent or built on a wrong premise. **Never merge a salvaged diff you haven't gated** — a
  half-applied change can pass a superficial read and still be broken; run the acceptance checks yourself.

Salvaged work is still *proposed* work: the gate rule (**subagent-framework** §0) doesn't relax because the
agent that produced it died.

## 4. Fix the cause before re-delegating

If the agent died on scope, ambiguity, or a missing design call, that's an **orchestrator bug, not an agent
bug** — re-issuing the same contract gets the same death. Re-scope it (tighter files, an explicit step
outline, the design call made up front) and count the retry against the §1b two-attempt bar. Log the death
and its cause in the delegation log; repeated deaths of the same shape are the signal that the task type
needs a different worker tier — or isn't delegatable at all.
