---
name: subagent-framework
description: Method for delegating work to subagents and measuring whether it worked — when to delegate, the task contract, size tiers, orchestration patterns (single/fan-out/pipeline/panel/adversarial-verify/repair), the eval scorecard, two-tier logging, and guardrails. Project-agnostic; the consuming repo supplies its concrete gate commands. Load before delegating any non-trivial task to a subagent, running an expert-review panel, or deciding whether a task is worth delegating at all.
user-invocable: false
---

# Subagent framework — running & evaluating delegated agents

How to delegate work to subagents and **measure whether it worked**. This is the method; the running
record lives in your project's **delegation log** (see §7). Goal: get the leverage of parallel, cheaper
agents **without** letting unverified output into the tree, and **without** orchestration overhead exceeding
the work saved.

> **This skill is parameterized.** Everywhere it says "the project gates" it means a small set of slots
> (§3a) whose concrete commands live in the consuming repo (typically its `CLAUDE.md`). Get that seam right
> and the same method drops into any repo — Svelte, Go, Python — unchanged. The skill defines the *slots*;
> the project supplies the *values*.

## 0. Principles
1. **The main loop owns the outcome.** A subagent's output is a *proposal*, done only after the main loop
   **observes** the gate pass.
2. **Gate truth comes from tool output, never the agent's prose.** A subagent may claim "check 0, tests
   pass" while the run failed or never happened. Re-run the gate yourself and read the exit status. Never
   infer success from the agent's description.
3. **Right-size the ceremony.** Match panel size, scorecard depth, and adversarial-verify to the stakes
   (§1a). The cheapest sufficient process wins.
4. **Delegate the work, keep the judgment.** Hand off scoped/mechanical/parallel work; keep design,
   architecture, ambiguity, and final synthesis in the main loop.
5. **Spec in, distilled result out.** Precise contract (§3); compact structured return so the main loop's
   context isn't flooded (never read raw agent transcripts into context).

**Standing rule (validated in practice):** delegating to a cheaper/faster model *is* worth it, but on a
strict division of labour — **the subagent does breadth + execution; the main loop keeps design +
verification.** Every delegation that holds to that split lands cleanly (review panels surface real findings
*because* the main loop synthesizes/verifies them and rejects the false positives; write tasks land one-shot
*because* the main loop pre-decided the design and re-ran the gates). The failure mode is the inverse —
letting a subagent make the design calls or self-certify its own gates. So: delegate for breadth (parallel
panels) and for execution (spec'd, test-guarded changes); never delegate the architecture or the gate.

## 1. When to delegate (decision matrix)

| Signal | Delegate (cheaper model) | Keep in main loop (strongest model) |
| --- | --- | --- |
| Scope | Well-bounded, spec'able | Ambiguous / discovery |
| Judgment | Mechanical / pattern-following | Architecture, API design, tradeoffs |
| Risk | Reversible, test-guarded | Visual baselines, invariants, security |
| Shape | Parallelizable / repetitive | Cross-cutting synthesis |
| Verifiability | Clear acceptance checks | "I'll know it when I see it" |

### 1a. Size thresholds (the "is it worth delegating?" gate)
- **Just do it in the main loop** when the task is **< ~15 min / < ~100 lines** of straightforward change —
  the contract-writing + logging + verification overhead exceeds the saving. *Exception:* delegate anyway if
  **parallelism** is the actual goal (N independent items at once).
- **Single subagent** for a bounded task above that line.
- **Parallel fan-out / panel** only when work is genuinely independent or needs multiple perspectives (§6).

## 2. Model & agent-type selection
- **Default coding/review model** (e.g. a mid-tier model) — the workhorse for delegated coding & structured
  review.
- **Strongest model** — main loop; design/synthesis; delegate to it only for a genuinely hard sub-problem.
- **Cheapest model** — trivial deterministic extraction only: collect a file list, grep-and-summarize one
  file, extract symbol names, a pure rename sweep. **Never a write task without a following gate** (repair
  cost of a bad cheap-model write is high).
- **Agent type:** a read-only search agent for read-only fan-out; a general/implementation agent for
  review/implementation (instruct read-only when it must not write). Worktree isolation **only** when
  multiple agents write in parallel (it costs ~hundreds of ms + disk each — not free).

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
   numbered step plan** — not just a goal. The main loop owns the decomposition and the hard design calls
   (resolve ambiguous/idiomatic choices *before* delegating); the subagent executes the steps. A goal-only
   prompt makes the agent re-derive design under-context and drift. Outlining steps is also where you catch
   that a task should be split or kept.

### 3a. Acceptance-check menu — the parameterized gate slots (pick what the task touches; don't run all by reflex)
The consuming repo fills each slot with a concrete command. The **slots** are stable; the **commands** are
the project's.

- **Always gate:** type/compile check + lint. *(run for every delegation)*
- **Logic/code gate:** unit tests — when the change touches logic.
- **UI/component gate:** an accessibility check (e.g. axe) — **first-class for any UI work, not optional**;
  run whenever a user-facing component or story is added/edited.
- **Visual-regression gate:** the project's VRT runner. *Bright-line trigger:* any change to a **styled /
  visual source file** (a component or stylesheet). Non-visual / test-only / logic-only changes skip it.
  *(If VRT needs a preflight — e.g. a container daemon — note it in the project's gate definition.)*

> **Project gates (filled in by the consuming repo).** The consuming `CLAUDE.md` should list, e.g.:
> *always = `<check>` + `<lint>`; logic = `<unit-test>`; UI a11y = `<a11y-test>`; VRT = `<vrt-runner>` (+ any
> preflight).* If a slot has no equivalent in the project, say so explicitly rather than skipping silently.

## 4. Orchestration patterns
- **Single delegate** — spec → run → **inspect the diff** (bound the expected size) → run the §3a gates the
  task touched → commit.
- **Parallel fan-out** — independent tasks in one batch (background). Cap concurrency. If they write, give
  each a **worktree**, then **join**: merge each worktree, and **re-run the always-gate (check + lint) on the
  unified tree** before committing (per-worktree green ≠ integrated green).
- **Pipeline** — produce → verify per item, no barrier, when stages don't need the whole set.
- **Panel / board review** — N discipline experts in parallel → main loop synthesizes (§6).
- **Adversarial verify** — a second agent (given **identical scope**) tries to *refute* a finding; a
  refutation without a cited counter-reason is invalid. **Default on for BLOCKER/MAJOR findings and any
  security/invariant surface; off for MINOR/NIT** (there, "uncertain → keep with a confidence caveat").
- **Repair loop** — feed the failing gate output back to the same agent. "Unproductive" = the **same** check
  still failing after a round. Cap: **1 round** for < ~1 h tasks, **2** for larger. On exhaustion, **escalate
  to the main loop**; if it was a worktree, **discard it** (`git worktree remove --force`), don't merge. If
  round 2 looks substantively like round 1, escalate immediately (don't send a 3rd).

## 5. Evaluation (the "eval" half)

**Gate (binary, observed by the main loop):** the §3a checks for what the task touched. No gate pass → not
done, regardless of how good it looks or what the agent claims.

**Scorecard — only for substantial (≥ ~2 h) or first-of-its-type delegations** (≤3 prior log entries of
that type). Below that, a one-line micro-log suffices (§7). Score 1–5:

| Dimension | 1 | 5 |
| --- | --- | --- |
| **Correctness** ¹ | Wrong / gate-red | Correct, gate-green |
| **Completeness** | Missed spec items | Covered the spec |
| **Scope adherence** ¹ | Touched out-of-scope | Stayed exactly in scope |
| **Quality/conventions** | Off-pattern | Idiomatic, matches codebase |
| **Autonomy** ² | Heavy hand-holding | One-shot, no repair |
| **Signal (reviews)** ³ | Hallucinated/uncited | Cited file:line + repro + concrete fix |

¹ **Hard floors override the average:** Correctness=1 → **❌**; any dimension ≤2 (esp. Correctness/Scope) →
at best **⚠️**. A 4.5 average can't launder a Correctness=1.
² If Autonomy <4, record **spec-gap vs agent-gap** — only a confirmed *agent-gap* should change future
delegation decisions (a bad spec is the orchestrator's fault).
³ Signal anchors: **5** = cited, reproducible, concrete fix; **1** = uncited, contradicts the actual code, or
hallucinated. Track a rough **false-positive rate** per reviewer.

**Roll-up:** **✅** (gate green, no hard-floor trip, ≤1 repair) · **⚠️-R** (green after repair) / **⚠️-I**
(useful but incomplete) · **❌** (gate red / Correctness=1). One line of "why" in the log.

**Calibration:** scan the log **before delegating a new task type, and every ~10 delegations**. A type that
repeatedly scores low → stop delegating / tighten the contract; consistently high → delegate by default.

## 6. The expert-review-board workflow (reusable)
1. **Size the panel to the surface** (don't reflex to five): **1–2 reviewers** for < ~200-line / single-
   discipline changes; **2–3** for a new component or cross-discipline surface; **full 5** (e.g. language/
   framework · architecture · a11y/UX · performance · QA) only for public-API/primitive or high-stakes
   architecture.
2. **Fan out** one reviewer per discipline, same scoped artifact + fixed schema
   (`**[SEVERITY]** area · file:line · finding · fix`, severity ∈ BLOCKER/MAJOR/MINOR/NIT). Instruct each:
   **don't hedge; prefer false positives to false negatives; cite file:line or it doesn't count.**
3. **Synthesize in the main loop** — de-dup, **verify each finding against the code** (trace it; reject false
   positives — this is mandatory, not rubber-stamping), assign final severity, sequence. **Multi-mention
   (≥2 disciplines) is a severity tiebreaker, NOT a validity signal** — the same model family reading the
   same artifact shares blind spots, so agreement can amplify bias. The validity check is reading the code
   (and adversarial-verify for BLOCKERs), not the vote count.
4. **Synthesis isn't free** — for a large artifact a 5-panel + de-dup can cost as much as one disciplined
   main-loop read; factor that into whether a panel is worth it.
5. **Persist** as a dated round in the project's research/review folder; turn accepted findings into tasks.

## 7. Logging (two-tier, with rotation)
Keep a **delegation log** in the repo (the project sets the path, e.g. `docs/subagent-log.md`).
- **Micro-log** (default): one line — date · task slug · model · ✅/⚠️/❌ · `gates:` run · `repair:` rounds.
- **Full entry** (scorecard + notes): only for first-of-type, scorecard-eligible (§5), or any ⚠️/❌.
- **Rotation:** once the log passes ~50 entries, collapse entries older than a few weeks into a *task-type ×
  outcome* frequency table; keep full entries only for ⚠️/❌ and first-of-type — so "scan the log" stays cheap.

## 8. Guardrails / anti-patterns
- **Never commit unverified output**; observe gates yourself (§0.2).
- **No context floods** — distilled returns; don't read agent transcript files into context.
- **Right-size** (§1a, §6.1) — a 50-line change doesn't need a 5-panel; a cheap-model rename doesn't need a
  scorecard.
- **Don't delegate the undelegatable** — ambiguous scope / product calls / no writable acceptance checks.
  Tighten to a spec first, or keep it.
- **Parallel writers isolate** (worktrees) **and join-verify** (§4).

## 9. Tooling map
- Subagent launch: the agent/task tool's `model`, `subagent_type`, background, and worktree-isolation
  options; a "continue this agent" message to resume the same agent (repair loop) **with its context intact**
  — relaunch from the transcript rather than spawning a fresh agent.
- Gates: prefer the project's named scripts for each §3a slot.
- Log every delegation per §7.
