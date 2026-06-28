# subagent-framework — reference detail

Reference-grade material for the `subagent-framework` skill: the evaluation scorecard, two-tier logging with
rotation, and the tooling map. The skill's `SKILL.md` carries the decision-critical core; this file is for
when you're scoring a substantial delegation or setting up the log — pull it in then, not on every task.

## Evaluation — the scorecard

**Gate (binary, observed by the main loop):** the §3a checks for what the task touched. No gate pass → not
done, regardless of how good it looks or what the agent claims.

**Scorecard — only for substantial (≥ ~2 h) or first-of-its-type delegations** (≤3 prior log entries of that
type). Below that, a one-line micro-log suffices. Score 1–5:

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

## Logging (two-tier, with rotation)
Keep a **delegation log** in the repo (the host repo sets the path).
- **Micro-log** (default): one line — date · task slug · model/role · ✅/⚠️/❌ · `gates:` run · `repair:`
  rounds.
- **Full entry** (scorecard + notes): only for first-of-type, scorecard-eligible, or any ⚠️/❌.
- **Rotation:** once the log passes ~50 entries, collapse entries older than a few weeks into a *task-type ×
  outcome* frequency table; keep full entries only for ⚠️/❌ and first-of-type — so "scan the log" stays cheap.

## Tooling map
- Subagent launch: the agent/task tool's `model`, `subagent_type`, background, and worktree-isolation
  options; a "continue this agent" message to resume the same agent (repair loop) **with its context
  intact** — relaunch from the transcript rather than spawning a fresh agent.
- Gates: prefer the host repo's named scripts for each §3a slot.
- Log every delegation per the two-tier scheme above.
