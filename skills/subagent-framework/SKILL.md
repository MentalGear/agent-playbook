---
name: subagent-framework
description: Use when delegating work to subagents — deciding whether a task is worth delegating, writing the task contract, choosing the orchestration pattern (single / parallel fan-out / pipeline / adversarial-verify / repair), and verifying the result before it lands. The core operating rules; the scorecard, logging, and tooling detail live in reference.md, and the review-panel pattern in the independent-expert-review skill. Project-agnostic — the host repo supplies its concrete gate commands. Load before any non-trivial delegation.
user-invocable: false
---

# Subagent framework — delegate work, keep the judgment

How to delegate to subagents and **measure whether it worked** — getting the leverage of parallel, cheaper
agents **without** letting unverified output into the tree, and **without** orchestration overhead exceeding
the work saved.

> **Parameterized skill — resolve these slots from the host repo (its `CLAUDE.md`):**
> - **Gate commands** for the §3a slots — *always* (type/compile check + lint), *logic* (unit tests),
>   *UI/a11y* (accessibility check), *visual-regression* (VRT runner + any preflight). If a slot has no
>   equivalent in this project, say so explicitly rather than skipping silently.
> - **Delegation log** path (§7 / reference.md).
>
> Companion skills: **independent-expert-review** (the review-panel pattern, §6 here) and the host repo's
> own conventions skills. Deeper rubric — scorecard, two-tier logging, tooling map — is in **reference.md**.

## 0. Principles
1. **The main loop owns the outcome.** A subagent's output is a *proposal*, done only after the main loop
   **observes** the gate pass.
2. **Gate truth comes from tool output, never the agent's prose.** A subagent may claim "check 0, tests
   pass" while the run failed or never happened. Re-run the gate yourself and read the exit status.
3. **Right-size the ceremony.** Match panel size, scorecard depth, and adversarial-verify to the stakes.
   The cheapest sufficient process wins.
4. **Delegate the work, keep the judgment.** Hand off scoped/mechanical/parallel work; keep design,
   architecture, ambiguity, and final synthesis in the main loop.
5. **Spec in, distilled result out.** Precise contract (§3); compact structured return so the main loop's
   context isn't flooded (never read raw agent transcripts into context).

**Standing rule (validated in practice):** delegating to a cheaper/faster model *is* worth it, but on a
strict division of labour — **the worker does breadth + execution; the orchestrator keeps design +
verification.** Every delegation that holds to that split lands cleanly. The failure mode is the inverse —
letting a subagent make the design calls or self-certify its own gates. Delegate for breadth and for
execution; never delegate the architecture or the gate.

## 1. When to delegate (decision matrix)

| Signal | Delegate to a worker | Keep with the orchestrator |
| --- | --- | --- |
| Scope | Well-bounded, spec'able | Ambiguous / discovery |
| Judgment | Mechanical / pattern-following | Architecture, API design, tradeoffs |
| Risk | Reversible, test-guarded | Visual baselines, invariants, security |
| Shape | Parallelizable / repetitive | Cross-cutting synthesis |
| Verifiability | Clear acceptance checks | "I'll know it when I see it" |

### 1a. Size thresholds (the "is it worth delegating?" gate)
- **Just do it in the main loop** when the task is **< ~15 min / < ~100 lines** of straightforward change —
  the contract-writing + logging + verification overhead exceeds the saving. *Exception:* delegate anyway if
  **parallelism** is the goal (N independent items at once).
- **Single worker** for a bounded task above that line.
- **Parallel fan-out / panel** only when work is genuinely independent or needs multiple perspectives
  (see the **independent-expert-review** skill).

## 2. Roles & model selection
Pick by **role**, then map the role to whatever model tier fits your provider:
- **Orchestrator** — the main loop. Owns design, decomposition, synthesis, and the gate. Use your strongest
  model; delegate *to* it only for a genuinely hard sub-problem.
- **Worker** — the default for delegated coding & structured review. A capable mid-tier model; does breadth
  and spec'd execution.
- **Extractor** — trivial deterministic work only (collect a file list, grep-and-summarize, extract symbol
  names, a pure rename sweep). A cheap/fast model. **Never a write task without a following gate** — the
  repair cost of a bad extractor write is high.
- **Agent type:** a read-only search agent for read-only fan-out; a general/implementation agent for
  review/implementation (instruct read-only when it must not write). Worktree isolation **only** when
  multiple agents write in parallel (it costs setup time + disk each — not free).

## 3. The task contract (every delegation states these)
1. **Role/goal** — one line.
2. **Scope** — exact files/dirs in/out (exclude generated/vendored code).
3. **Context** — design intent (link the plan), project conventions, the skill(s) to consult.
4. **Constraints** — read-only vs may-write; don't touch X; isolation mode.
5. **Acceptance checks** — what "done" means (§3a).
6. **Output format** — compact structured return; "your final message IS the deliverable." Fixed schema for
   reviews.
7. **Budget/parallelism** — background? batch? worktree?
8. **Step outline (the orchestrator's job).** For any non-trivial task, **design and hand over an ordered,
   numbered step plan** — not just a goal. The orchestrator owns the decomposition and the hard design calls
   (resolve ambiguous/idiomatic choices *before* delegating); the worker executes. A goal-only prompt makes
   the agent re-derive design under-context and drift. Outlining steps is also where you catch that a task
   should be split or kept.

### 3a. Acceptance-check menu — the parameterized gate slots (pick what the task touches; don't run all by reflex)
The host repo fills each slot with a concrete command (see the slot list at the top). The **slots** are
stable; the **commands** are the project's.
- **Always gate:** type/compile check + lint. *(every delegation)*
- **Logic/code gate:** unit tests — when the change touches logic.
- **UI/component gate:** an accessibility check (e.g. axe) — **first-class for any UI work, not optional**.
- **Visual-regression gate:** the project's VRT runner. *Bright-line trigger:* any change to a styled/visual
  source file (a component or stylesheet). Non-visual / test-only / logic-only changes skip it.

## 4. Orchestration patterns
- **Single delegate** — spec → run → **inspect the diff** (bound the expected size) → run the §3a gates the
  task touched → commit.
- **Parallel fan-out** — independent tasks in one batch (background). Cap concurrency. If they write, give
  each a **worktree**, then **join**: merge each worktree, and **re-run the always-gate on the unified tree**
  before committing (per-worktree green ≠ integrated green).
- **Pipeline** — produce → verify per item, no barrier, when stages don't need the whole set.
- **Panel / board review** — N discipline experts in parallel → main loop synthesizes. See the
  **independent-expert-review** skill for the full workflow (sizing, neutral-reviewer contract, finding
  schema, verification).
- **Adversarial verify** — a second agent (given **identical scope**) tries to *refute* a finding; a
  refutation without a cited counter-reason is invalid. **Default on for BLOCKER/MAJOR and any
  security/invariant surface; off for MINOR/NIT.**
- **Repair loop** — feed the failing gate output back to the **same** agent. "Unproductive" = the same check
  still failing after a round. Cap: **1 round** for < ~1 h tasks, **2** for larger. On exhaustion, **escalate
  to the main loop**; if it was a worktree, **discard it** (`git worktree remove --force`), don't merge.

## 5. Verify before it lands
**Gate (binary, observed by the main loop):** the §3a checks for what the task touched. No gate pass → not
done, regardless of how good it looks or what the agent claims. **Read the diff** before committing.

For substantial or first-of-its-type delegations, score the result and log it — the **scorecard rubric,
two-tier logging, and rotation** live in **reference.md**.

## 6. Guardrails / anti-patterns
- **Never commit unverified output**; observe gates yourself (§0.2).
- **No context floods** — distilled returns; don't read agent transcript files into context.
- **Right-size** — a 50-line change doesn't need a 5-panel; an extractor rename doesn't need a scorecard.
- **Don't delegate the undelegatable** — ambiguous scope / product calls / no writable acceptance checks.
  Tighten to a spec first, or keep it.
- **Parallel writers isolate** (worktrees) **and join-verify** (§4).

---
*Reference detail (scorecard, logging, tooling map): see `reference.md` in this skill. Review panels: see
the `independent-expert-review` skill.*
