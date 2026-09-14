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

### Tier fit — make the tier table falsifiable

`SKILL.md` §2 maps task shapes to model tiers. That mapping is **asserted, not measured** — nothing in it
could currently be proven wrong. The log is where it earns or loses its claim, at almost no extra cost: the
micro-log already carries model/role and outcome; add the **task class** and you have the cell.

**Record per delegation (4 fields, all already at hand):** `tier` · `task class` · `outcome` (gate passed
first try / N repair rounds / escalated to the main loop) · `repair cause` when there was one.

**Read it by class, never by instance.** "Was this tier right for this delegation?" is unanswerable — §1b
already says a worker that drifts is *usually* an under-specified brief, so a per-instance tier verdict
mostly measures brief quality wearing a tier label. The pattern across a class is what carries signal:

- A class that repeatedly needs repair rounds at the cheap tier → **promote** it.
- A class that always passes first try at the strongest tier → **demotion candidate** (see the probe below).
- A class whose repair causes cluster on *scope and ambiguity* rather than capability → the brief is the
  problem, not the tier. Fix §3 before touching §2.

**Budget a deliberate downshift probe.** You only ever observe the tier you chose, never the one you didn't
— so "the tier I picked worked" is the only thing repeated success can teach you, and the table **ratchets
upward forever**. Once a class has been stable for several delegations, run one deliberately a tier cheaper
and see whether it holds. That single counterfactual is what separates a measured mapping from a habit.

A tier table with no downshift probe behind it is a record of what you have been willing to pay, not of
what the work costs.

## Tooling map
- Subagent launch: the agent/task tool's `model`, `subagent_type`, background, and worktree-isolation
  options; a "continue this agent" message to resume the same agent (repair loop) **with its context
  intact** — relaunch from the transcript rather than spawning a fresh agent.
- Gates: prefer the host repo's named scripts for each gate in the `project-gates` manifest.
- Log every delegation per the two-tier scheme above.
