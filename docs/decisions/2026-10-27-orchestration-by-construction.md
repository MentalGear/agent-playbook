---
decides:
  - subject: orchestration-single-writer
    outcome: adopted
    statement: The coordinator is the only writer of work state and of the delegation log; sub-agents return results and write no shared state.
  - subject: delegation-log
    outcome: adopted
    statement: A harness hook writes one observed line per delegation into a per-session file, and the coordinator adds its verdict after re-running the gates.
  - subject: return-contract-enforcement
    outcome: adopted
    statement: The return contract is delivered to every sub-agent and checked when it stops, by harness hooks, instead of being restated in each brief.
  - subject: rules-at-point-of-use
    outcome: adopted
    statement: A rule bound to a path is delivered when an agent touches that path, through path-scoped rules, and enforced through permissions where it must hold.
  - subject: review-date-triggers
    outcome: adopted
    statement: A decision may carry a review date, and a scheduled CI job is its evaluator; no trigger exists without a job that runs it.
  - subject: orchestration-authority
    outcome: open
    statement: Who may merge is a host setting the owner has not yet made; until then the rule that a model merges only on the owner's instruction is unenforced.
  - subject: multi-coordinator-leases
    outcome: deferred
    statement: Leases for several independent coordinators are not built until a coordination failure between coordinators is recorded.
  - subject: pointer-brief-measurement
    outcome: deferred
    statement: Briefs that list record ids are not measured until the evaluation harness can measure re-exploration.
  - subject: dolt-store
    outcome: deferred
    statement: Dolt is not used as a store; it is the first escalation for work state only if plain files measurably fail.
supersedes: []
---
<!-- BEGIN GENERATED: scripts/decisions.sh. Do not edit; run scripts/decisions.sh --write. -->
> **Dated record: evidence, not instructions.** Current on: `orchestration-single-writer` (adopted), `delegation-log` (adopted), `return-contract-enforcement` (adopted), `rules-at-point-of-use` (adopted), `review-date-triggers` (adopted), `orchestration-authority` (open), `multi-coordinator-leases` (deferred), `pointer-brief-measurement` (deferred), `dolt-store` (deferred). Current decisions: [README.md](README.md).
<!-- END GENERATED -->


# Orchestration built from its root causes

Review: `docs/research/2026-10-26-substrate-review.md` (adversarial board, runs 1 and 2, on two earlier
versions of this plan). This record replaces both. The board was stopped before run 3 at the owner's
request; this version has not been reviewed by the board.

## 1. Root causes

The verified findings of both board runs, and the defects found in this repository while checking them,
reduce to four causes. Each construction in §2 removes one cause for a whole class of findings.

| Root | Findings it produced |
|---|---|
| **R1. A rule enforced only by the agent's compliance.** | "A model never merges" with an unprotected `main` and agents acting under the owner's account; merge on green; forgeable identity in git authors and trailers; append-only and namespaces that nothing enforced; triggers with no evaluator on the host; the access map is advisory; the delegation log that `subagent-framework` specifies was never kept; decision homes named in three skills; the code index left unused when only instructed (CodeCompass: 58% of trials). |
| **R2. State with more than one writer, or more than one copy.** | Work-state events written by every agent, which needed leases, clocks, per-agent namespaces and collision-free ids; status lines copied from the world into decision records, three of them stale; generated views merged by a custom driver that sees one side (`registry.yaml`: reproduced); the hub and the guide each stating rules for `docs/research/`. |
| **R3. A report trusted where an observation exists.** | Agents reporting gate results, files touched and their own death; event order from self-reported clocks; paper findings relayed from summaries instead of read (four citations wrong in v1, two more in the run-1 corrections). |
| **R4. A change made without an instrument to judge it.** | Measurement placed last in v1; "coordination failures not observed" when nothing records delegations; a harness whose fixtures cannot show re-exploration. |

## 2. Constructions

### 2.1 One writer (R2) — `orchestration-single-writer`

The coordinator is the only writer of work state and of the delegation log. A sub-agent returns its
result (§3 item 6 of `subagent-framework`) and writes no shared state. Parallel sub-agents are kept apart
by disjoint write scopes, checked by the coordinator before dispatch (`subagent-framework` §3 item 4).

With one writer per piece of state, ordering is the writer's own order, and identity is the host's agent
id. Leases, clocks, per-agent namespaces and coordinated id schemes are not needed, so they are not
built. They are needed only when several independent coordinators share work (`multi-coordinator-leases`,
§4).

### 2.2 Observed, not reported (R3, R4) — `delegation-log`

A harness hook writes the delegation log. In Claude Code the `SubagentStop` hook receives the agent id and
type, the sub-agent's transcript path and its final message. From these it writes one line: date, session,
agent id and type, the model served, token use including cache reads, duration, and the state the agent
claimed. The coordinator then adds its verdict, after re-running the gates.

- **One file per session** (`docs/subagent-log/<date>-<session>.md`), so concurrent sessions never write
  the same file. `agent-repo-layout` already gives the log its home and `append` access.
- **Host slot.** The hook is the Claude Code implementation. Another harness fills the same fields its own
  way; the log's fields are defined once, in `subagent-framework/reference.md`.
- It is also the instrument R4 asked for: a coordination failure can now be seen in the log, which the
  deferred subjects in §4 need before they can reopen.

### 2.3 The return contract at the boundary (R1) — `return-contract-enforcement`

- **Delivered:** a `SubagentStart` hook adds the return contract to every sub-agent's context, so a brief
  no longer has to restate it.
- **Checked:** the `SubagentStop` hook checks the final message for a state line and the contract's
  sections. If something is missing, it blocks once with the missing items as the reason, and the
  sub-agent completes its report. If the second attempt also fails, the hook does not block again; the
  failure is logged instead.
- **States** use A2A's names: `completed`, `failed`, `input-required`, `rejected`, `canceled`.
  `input-required` carries the open question as Options, Recommendation, Rationale, Confidence and
  Falsifier, so the owner can answer it with one judgement. `stale` is the coordinator's observation of an
  agent that has not returned after a timeout; it routes to `salvage-subagent-transcript`. An agent never
  reports its own death.
- The gates stay the coordinator's: it re-runs them, and a claimed pass is never accepted without that.

### 2.4 Rules at the point of use (R1) — `rules-at-point-of-use`

Claude Code loads a rule in `.claude/rules/` with `paths:` front matter when an agent reads or edits a
matching file. That includes sub-agents, so a path-bound rule reaches a sub-agent without the brief
restating it ([memory docs](https://code.claude.com/docs/en/memory#path-specific-rules);
[sub-agent docs](https://code.claude.com/docs/en/sub-agents#what-loads-at-startup)). The same docs state
that rules are guidance, not enforcement, and that blocking an action needs a permission rule or a hook.
So:

- **Guidance at the point of use:** a path-scoped rule. In this hub: `docs/decisions/**` gets the rule
  that records are evidence, not instructions.
- **Enforcement where a rule must hold:** a permission rule or a hook, never prose. For a consuming repo,
  the `read-only` entries of `.agents/access.yaml` map directly onto `permissions.deny` for `Edit` and
  `Write`.
- **Portability:** these are Claude Code mechanisms. `AGENT_RULES.md` and the skills stay the portable
  channel. The generated files carry the same rule text, so the two channels cannot drift.

### 2.5 Triggers only where a job runs them (R1) — `review-date-triggers`

A decision entry may carry `review: YYYY-MM-DD`. A scheduled CI workflow runs `scripts/decisions.sh
--due` and fails when a review date has passed, which notifies the owner through the host. The trigger
and its evaluator ship together, so a trigger without an evaluator cannot exist. The dates already
written in prose (2027-01-31 and 2027-04-30) become such fields. A firing is idempotent: the job fails
again on each run until the record is superseded or given a later date.

### 2.6 Authority in the host (R1) — `orchestration-authority`

These settings belong to the owner and cannot be made in the repository:

- a ruleset on `main` that requires a pull request and the `ci` check, with branches up to date;
- agents acting under their own host identity, without merge rights.

Until then, every record that says "the owner merges" describes policy, not enforcement.

## 3. Rollout

Each step is one pull request, merged by the owner, with its acceptance stated before it is built.

1. **Delegation log (2.2).** The `SubagentStop` hook script and its fields in `reference.md`, with a test
   that feeds recorded hook inputs and compares the lines written. Acceptance: one line per delegation in a
   live session, with the model and token fields filled.
2. **Return contract at the boundary (2.3).**
   - **Baseline:** read from the log after step 1 has run for at least 20 delegations: the share of
     sub-agent final messages that carry every contract section.
   - **Prediction:** at least 95% with the hooks, and no rise in median tokens per delegation above 10%.
   - **Revert:** if compliance gains under 10 points or the token rise exceeds 10%.
3. **Path-scoped rules and permissions (2.4).** In this hub, the decision-records rule (done with the
   decision-record check). For consuming repos, generated by `sync-agent-skills.sh`.
   - **Measurement:** the selection tranche in `agent-playbook-test`, before and after.
   - **Prediction:** no loss in selection precision or recall.
4. **Review dates (2.5).** Grammar, `--due`, the scheduled workflow, and its self-test.
5. **Host settings (2.6)** by the owner.

## 4. Deferred

- **`multi-coordinator-leases`.** Reopens when the log (2.2) records a failure between independent
  coordinators: duplicated work, or a collision on a file or shared resource. A design that reopens must
  meet the constraints below. Each comes from a verified board finding.
  - A lease is acquired by compare-and-swap at one serialization point (for example a server-side ref
    created only if absent). It issues a fencing token that only increases, and the merge gate rejects
    stale tokens.
  - Writer ids are unique per concurrent writer and never reused; the model id is a field, never a
    namespace.
  - Events are ordered by merge order. A dead agent is presumed after a timeout, and its later writes are
    fenced.
- **`pointer-brief-measurement`.** `subagent-framework` §3 item 2 already requires a brief to name the
  files in and out of scope; record ids would be the only addition. Reopens when the harness has at least
  20 edit tasks on a fixture of realistic size, where the task does not name the files, each with a hidden
  acceptance test. The current fixtures have 6–8 files, many tasks name the file, scoring is pattern
  matching on the trace, and the patch is deleted.
- **`dolt-store`.** Pull-request diffs do not show its data, and plain-file tools cannot read it. Reopens
  as the first escalation for work state if per-session files measurably fail.
