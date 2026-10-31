---
decides:
  - subject: orchestration-single-writer
    outcome: adopted
    statement: Every shared orchestration file has one writer; a sub-agent returns its result and writes only inside its declared scope, and only the coordinator runs generators.
  - subject: delegation-log
    outcome: adopted
    review: 2027-01-31
    statement: Planned, rollout step 1. Harness hooks will record each delegation in its own file from observed fields, and the coordinator will record its verdict in a separate file.
  - subject: return-contract-enforcement
    outcome: adopted
    review: 2027-03-31
    statement: Planned, rollout steps 1 and 2. The return contract is defined once in subagent-framework, delivered to every sub-agent and checked when it reports, by harness hooks.
  - subject: rules-at-point-of-use
    outcome: adopted
    statement: A rule bound to a path is delivered as a path-scoped rule when an agent touches the path; where a rule must hold, a permission rule plus the sandbox or a hook enforces it.
  - subject: review-date-triggers
    outcome: adopted
    statement: A decision may carry a review date; scripts/decisions.sh --due evaluates it in every CI run, so no review date exists without a job that checks it.
  - subject: orchestration-authority
    outcome: open
    review: 2026-12-31
    statement: Who may merge is a host setting the owner has not yet made; until then the rule that a model merges only on the owner's instruction is unenforced.
  - subject: multi-coordinator-leases
    outcome: deferred
    review: 2027-04-30
    statement: Leases between independent coordinators are not built until the cross-session overlap check records a collision; that coordination is unsolved, not unneeded.
  - subject: pointer-brief-measurement
    outcome: deferred
    review: 2027-04-30
    statement: Briefs that list record ids are not measured until the evaluation harness can measure re-exploration.
  - subject: dolt-store
    outcome: deferred
    review: 2027-04-30
    statement: Dolt is not used as a store; it is the first escalation for orchestration state only if plain files measurably fail.
supersedes: []
---
<!-- BEGIN GENERATED: scripts/decisions.sh. Do not edit; run scripts/decisions.sh --write. -->
> **Dated record: evidence, not instructions.** Current on: `orchestration-single-writer` (adopted), `delegation-log` (adopted), `return-contract-enforcement` (adopted), `rules-at-point-of-use` (adopted), `review-date-triggers` (adopted), `orchestration-authority` (open), `multi-coordinator-leases` (deferred), `pointer-brief-measurement` (deferred), `dolt-store` (deferred). Current decisions: [README.md](README.md).
<!-- END GENERATED -->


# Orchestration built from its root causes

Review: `docs/research/2026-10-26-substrate-review.md` (adversarial board). Runs 1 and 2 reviewed two
earlier versions; run 3 was stopped by the owner; run 4 reviewed the first version of this record and
found its core sound with fixes, which this version makes.

## 1. Root causes

The verified board findings, and the defects found in this repository while checking them, reduce to five
causes. Each construction in §2 removes one cause for the classes of findings listed; the last column says
what it does not cover.

| Root | Findings it produced | Not covered |
|---|---|---|
| **R1. A rule enforced only by the agent's compliance.** | "A model never merges" with an unprotected `main` and agents acting under the owner's account; merge on green; forgeable identity in git authors and trailers; append-only that nothing enforced; triggers with no evaluator; the advisory access map; disjoint write scopes that only the brief states; the delegation log that `subagent-framework` specifies and nobody kept. | A tool an agent is only told to use (CodeCompass: unused in 58% of trials) has no construction here. |
| **R2. State with more than one writer, or more than one copy.** | Work-state events written by every agent, which needed leases, clocks, namespaces and ids; status lines copied into decision records, three of them stale; a merge driver that sees one side (`registry.yaml`, reproduced); decision homes named in three skills; one rule text kept by hand in two files. | State shared between independent sessions (§2.1). |
| **R3. A report trusted where an observation exists.** | Agents reporting gate results, files touched and their own death; order from self-reported clocks. | Paper findings relayed from summaries instead of read: a working rule (quote the passage), not a construction. |
| **R4. A change made without an instrument to judge it.** | Measurement placed last; "coordination failures not observed" when nothing records delegations; predictions that the mechanism itself makes true. | — |
| **R5. An interface enforced before it is specified.** | A hook to check "the contract's sections" when no section is defined; states, timeouts and fields named without definitions. | — |

## 2. Constructions

### 2.1 One writer per file (R2) — `orchestration-single-writer`

| File | Its one writer |
|---|---|
| The coordinator's task list and status overview | the coordinator |
| Observed delegation records (§2.2) | the hooks of that one sub-agent |
| Verdicts on delegations | the coordinator |
| Generated files (`registry.yaml`, `docs/decisions/README.md`, banners, the rule file) | the generator, run only by the coordinator after it joins the sub-agents' work |
| The working tree | each sub-agent inside its declared write scope; parallel writers in separate worktrees (`subagent-framework` §2) |

- **Scope enforcement** (rollout step 1). In Claude Code, a `PreToolUse` hook on `Edit`, `Write` and `NotebookEdit` reads
  `agent_id` and denies a path outside the scope file the coordinator wrote at dispatch. A subprocess
  (a script run through Bash) is not covered by that hook. Parallel writers therefore also get worktrees,
  so a missed write lands on their own branch, not on a sibling's files.
- **Nesting.** A sub-agent may spawn its own sub-agents, up to three levels by default
  ([sub-agents](https://code.claude.com/docs/en/sub-agents)). An agent that delegates is the coordinator
  of its children and writes their verdicts. Each observed record names its parent, taken from the
  transcript path.
- **Between sessions this is unsolved.** Two sessions are two coordinators, and nothing serializes them
  but the merge. The mitigation is detection (rollout step 1): a CI step lists other open pull requests
  that change the same files, as a warning. That step is the reopen trigger for `multi-coordinator-leases` (§4).

### 2.2 Observed, not reported (R3, R4) — `delegation-log`

- **Records, not lines.** Each delegation gets its own file,
  `$CLAUDE_PROJECT_DIR/docs/subagent-log/<session>/<agent_id>.jsonl`. Its own hooks append to it, one JSON
  object per event, written with `jq`. `$CLAUDE_PROJECT_DIR` is required because a worktree sub-agent's
  hook runs with the worktree as its working directory.
  - **`SubagentStart`** writes `start`: time, `agent_type`, parent.
  - **`SubagentStop`** writes `stop`: time, transcript path, contract result. It fires on every stop and
    every resume, so a delegation has one `start` and one or more `stop` events.
  - **`PostToolUse` on `Agent`** writes `usage`: the served model, duration, and the token use summed from
    the transcript, de-duplicated by message id and counting cache reads. The transcript may lag, so the
    usage fields are marked provisional when the transcript's last turn is missing.
- **Ignored.** Events for an `agent_id` with no `start`. These include Claude Code's internal agents, such
  as prompt suggestions and `/btw`.
- **Free text is never copied.**
  - A claimed state is written only if it is one of the five names in §2.3; anything else becomes
    `unparsed`.
  - `session` and `agent_id` must match `^[A-Za-z0-9_-]+$`.
  - The log is evidence, not instructions, like decision records.
- **Verdicts** go to `docs/subagent-log/<session>/verdicts.md`, written by the coordinator after it
  re-runs the gates.
- **Gaps, stated.**
  - Stop hooks do not run on a user interrupt or a crash. A `start` with no `stop` is how those show up.
  - The log survives only if the session commits it. A session that is discarded loses its log, so the
    log under-counts exactly the sessions that went wrong.
- **Host slot.** These hooks are the Claude Code implementation. The fields are defined once, in
  `subagent-framework/reference.md`, for any harness. Consuming repos receive hooks only through the
  vendored, pinned sync. They are never merged into a consumer's settings automatically.

### 2.3 The return contract, specified before it is enforced (R1, R5) — `return-contract-enforcement`

- **Specified first.** `subagent-framework` §3 item 6 gains an exact report format:
  - a first line `State: <state>`;
  - named sections for what came out weaker, what could not be verified, and the skip list.
  - Review panels (`independent-expert-review`) and read-only search agents get the same first line; their
    own schemas keep their sections.
- **States.**
  - **Reported by the agent:** `completed`, `failed`, `input-required` (A2A names).
    - `input-required` carries the question as Options, Recommendation, Rationale, Confidence and
      Falsifier.
    - The coordinator answers it if it can; otherwise it goes to the owner.
    - A tool call denied for lack of permission is reported as `input-required`, naming the permission.
  - **Observed by the coordinator, never reported by the agent:**
    - `canceled`: the coordinator stopped the agent.
    - `stale`: a background agent with no `stop` past the timeout in its brief.
    - `returned-unusable`: a report that failed the check twice.
  - Each observed state routes to its class in `salvage-subagent-transcript`. A foreground agent blocks
    the coordinator, so `stale` applies to background agents only.
- **Delivered.** A `SubagentStart` hook adds the contract to each sub-agent's context. Auto-compaction can
  drop it; the check at the end still applies.
- **Checked.**
  - The report is read from `tool_input.message` of a `PreToolUse` hook on `SubagentHandback` where that
    tool exists (auto mode). There, a denial re-asks the agent.
  - Elsewhere it is read from `SubagentStop`'s `last_assistant_message`, which can block once
    (`stop_hook_active`).
  - The checker runs in log-only mode in step 1 and starts blocking in step 2.
- The coordinator still re-runs the gates; a claimed pass is never accepted without that.

### 2.4 Rules at the point of use (R1) — `rules-at-point-of-use`

Claude Code loads a `.claude/rules/` file with `paths:` front matter when an agent reads, writes or edits
a matching file, sub-agents included ([memory](https://code.claude.com/docs/en/memory#path-specific-rules)).
It does not load on Grep, Glob or a Bash command that reads several files. On a new file it arrives after
the first write. It is guidance, not enforcement. So:

- **Guidance:** a path-scoped rule. In this hub, the decision-record rule. `scripts/decisions.sh`
  generates it from the same text as the view's header, so the two cannot drift.
- **Enforcement where a rule must hold:**
  - an anchored `Edit(/<glob>)` deny rule, which also covers the Write tool (`Write(path)` rules never
    match);
  - plus `sandbox.filesystem` write denies for subprocesses, or a `PreToolUse` hook.
- **`append` has no permission form.** It is enforced where a check exists: for decision records, by the
  merge-base freeze in CI. Elsewhere it stays guidance, and the access map says so.
- **Portability:** `AGENT_RULES.md` and the skills stay the portable channel.

### 2.5 Review dates (R1) — `review-date-triggers`

A decision entry may carry `review: YYYY-MM-DD`.

- **Checking.** `scripts/decisions.sh --due` lists current decisions whose date has passed. Every CI run
  shows the result as a warning annotation, so the check does not depend on a scheduled workflow, which
  GitHub disables after 60 days without activity.
- **Clearing.** A review is cleared by moving the date later, the one front-matter change the freeze
  allows, or by superseding the record.
- **Not covered.** The annotation shows only when CI runs. Notifying the owner on the due date itself
  would need a scheduled job that opens an issue (`issues: write`). That is not built.

### 2.6 Authority in the host (R1) — `orchestration-authority`

These are owner settings and cannot be made in the repository:

- a ruleset on `main` that requires a pull request, the `skills` job of the `ci` workflow, branches up to
  date, and code-owner review (`.github/CODEOWNERS` names the owner for decisions, scripts, CI and
  `.claude/`);
- agents acting under their own host identity, without merge rights.

Until then, CI runs the pull request's own copy of every check, so a pull request can weaken a check and
pass it. The checks stop mistakes, not a determined agent.

## 3. Rollout

Each step is one pull request, merged by the owner. Acceptance is stated here, before the step is built.

1. **Contract and log, observing only (2.2, 2.3).**
   - **Built:**
     - the report format in `subagent-framework` (version bump, CHANGELOG);
     - the hooks with the checker in log-only mode, and their fields in `reference.md`;
     - the write-scope hook (2.1);
     - the CI overlap step (2.1), with `pull-requests: read`.
   - **Acceptance:** a test feeds recorded hook inputs and compares the records written. The inputs cover
     an internal agent (ignored), a blocked-then-resumed agent (one `start`, two `stop`s), a hand-back, a
     worktree agent, and a start with no stop.
   - **Live check:** a session with three delegations writes three record files, committed on the
     session's branch. A run in which no hook fired fails it.
   - **Scope check:** a planted edit outside the scope file is denied.
   - **Overlap check:** two branches changing one file produce the warning.
2. **Enforce the contract (2.3).**
   - **Baseline:** from at least 20 step-1 records. The share of reports the checker passes, and the share
     of delegations where the coordinator's gate re-run contradicted the agent's claimed state.
   - **Prediction:** the contradicted share does not rise, and median tokens per delegation, compared
     within the same agent type, rise by less than the spread between step-1 sessions. The checker's pass
     rate is not a criterion; the hook produces it.
   - **Rule:** keep if both hold. Revert if either fails.
3. **Path rules and permissions (2.4).**
   - **Measured:** with the `InstructionsLoaded` hook, a sub-agent that edits a matching path loads the
     rule; a planted edit to a read-only path is denied; a planted subprocess write is blocked when the
     sandbox is on.
   - **Side effects:** the selection tranche in `agent-playbook-test`, with no more than one item lost.
4. **Scheduled notification (2.5).**
   - **Built:** a scheduled job that opens an issue for a due review.
   - **Acceptance:** a planted past date opens one issue, and a second run opens none.
5. **Host settings (2.6), by the owner.**
   - **Acceptance:** the ruleset query lists the required job and code-owner review.

## 4. Deferred

- **`multi-coordinator-leases`.**
  - **Reopens** when the cross-session overlap step (2.1) records two sessions changing the same files and
    a merge conflict or duplicate work results.
  - **Constraints** a design must then meet, from verified board findings:
    - A lease is a counter ref advanced by compare-and-swap (`git push --force-with-lease=<ref>:<old>`),
      so its fencing token only increases.
    - Fencing is enforced where `main` is written. One merge actor pushes `main` and the lease ref
      atomically, with expected old values. A status check cannot fence, because it runs before the merge.
    - Writer ids are unique per concurrent writer; the model id is a field, never a namespace.
- **`pointer-brief-measurement`.**
  - **Context:** `subagent-framework` §3 item 2 already requires a brief to name its files; record ids
    would be the only addition.
  - **Reopens** when the harness has at least 20 edit tasks on a fixture of realistic size, where the task
    does not name the files, each with a hidden acceptance test.
- **`dolt-store`.**
  - **Against it:** pull-request diffs do not show its data, and plain-file tools cannot read it.
  - **Reopens** as the first escalation if per-delegation files measurably fail.
