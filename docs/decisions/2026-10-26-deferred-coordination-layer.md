---
decides:
  - subject: multi-agent-coordination-substrate
    outcome: deferred
    statement: The hub builds no coordination layer (agent identities, work-state records, leases, a typed status protocol, record triggers) until a coordination failure is recorded.
  - subject: pointer-brief-measurement
    outcome: deferred
    statement: Briefs listing record ids for a fresh sub-agent are not measured until the evaluation harness has a task bank that can measure re-exploration.
  - subject: dolt-store
    outcome: deferred
    statement: Dolt is not used as a store; it is the first escalation for a work-state layer, if one is built and plain files measurably fail.
supersedes: []
---

# Deferred: a coordination layer for parallel agents, pointer-brief measurement, and Dolt

Review: `docs/research/2026-10-26-substrate-review.md` (adversarial board, runs 1 and 2). The adopted part
of the same plan is `2026-10-26-decision-records-and-guide-route.md`.

Related: `2026-09-13-deferred-agent-mechanisms.md` §2 defers live messaging between agents. A status
protocol's `input-required` state would be the upward half of that channel. This record does not change
that deferral.

## 1. The coordination layer (`multi-agent-coordination-substrate`)

**What is not built:** identities for agents, per-agent record namespaces, work-state event records,
leases, a typed status protocol at every delegation edge, record triggers (time, condition, falsifier),
content hashes on references, and a knowledge-graph view.

**Why deferred.** No coordination failure is recorded in this hub. That is partly because nothing records
one: the hub keeps no delegation log. `subagent-framework` §3 (disjoint write scopes per brief, the return
contract) and `salvage-subagent-transcript` (agents that die mid-task) are the mitigations already in place.
The evidence does not show that a protocol format adds to them:

- **MAST** (Cemri et al., [arXiv:2503.13657](https://arxiv.org/abs/2503.13657), appendix H, Table 5). In
  the ChatDev case study, prompt changes (clearer roles, a verifier focused on edge cases) raised ProgramDev
  task completion from 25.0% to 34.4%. A topology change on top of them (the run ends only when one agent
  confirms) raised it to 40.6%. On HumanEval the same changes moved 89.6% to 91.5%, and the authors say the
  interventions "do not constitute substantial improvements". None of them was a message format.
- **Google Research** (Kim et al., [arXiv:2512.08296](https://arxiv.org/abs/2512.08296), and the
  [blog post](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/)). Independent
  agents amplified errors 17.2×, against 4.4× under a central orchestrator, and multi-agent set-ups lost
  39–70% on sequential tasks. The hub already uses a central orchestrator, and nothing here argues for peer
  coordination.

**What would reopen it:** a recorded coordination failure, in this hub or in a consuming repository:
duplicated work, a collision on a file or shared resource, or a lost status report, with its trace. Report
it as an issue on the hub repository or as a finding record. Review date without such a report: 2027-04-30.

**Constraints on a design that reopens.** Each one comes from a verified review finding.

- **Writer ids** are unique per concurrent writer (for example a session id plus an agent or task id) and
  never reused. The model id is a field, never a namespace.
- **Leases.** A lease is acquired by compare-and-swap at one serialization point, for example creating a
  server-side ref that fails if it exists. It issues a fencing token that only increases, and the protected
  resource, the merge gate, rejects stale tokens. A file in the tree is not a lease: it is invisible until it
  is merged.
- **Order.** Events are ordered by merge order, and illegal transitions are rejected at merge. A per-item
  sequence number is allocated through the same compare-and-swap point, never as "highest plus one".
- **States** use A2A's names at a pinned spec version. A dead agent is presumed after a timeout, observed by
  the coordinator, never self-reported. Its later writes are fenced.
- **Reports.** The `subagent-framework` return contract (§3.6) stays the set of claimed fields. Observed
  fields come from tools, and the top-level coordinator re-runs the gates.
- **Triggers** are valid only when their evaluator is installed on the host. A firing is idempotent, keyed
  by record and trigger. A firing over the rate limit is deferred and recorded, never dropped.
- **Reference hashes,** if any, apply only to references to records that state a falsifier, and name who
  re-approves a flagged reference.
- **Review panels** stay independent: reviewers do not message each other.
- **Authority.** Agents act under their own host identity, without merge rights.

## 2. Pointer briefs (`pointer-brief-measurement`)

**The candidate:** a brief for a fresh sub-agent lists the relevant record ids as well as the relevant
files. `subagent-framework` §3 item 2 already requires every brief to name the exact files and directories
in and out of scope, so record ids are the only new part. An architecture overview page is not a
candidate. Gloaguen et al. ([arXiv:2602.11988](https://arxiv.org/abs/2602.11988), preprint) found that
context files did not help as repository overviews and raised inference cost by over 20%.

**Why deferred.** The harness in `agent-playbook-test` cannot measure re-exploration:

- its fixtures have 6–8 files;
- many tasks name the file to edit;
- scoring matches the trace against patterns and runs no test of the result;
- the workspace is deleted after each run, so the patch is not kept.

**What would reopen it:** a task bank of at least 20 edit tasks on a fixture of realistic size, where the
task does not name the files, each with a hidden acceptance test and the patch saved. The design then
fixes these in advance:

- one statistic: the paired per-task median over rounds, n = number of tasks;
- one threshold with an action on each side;
- a non-inferiority margin for task success;
- runs with no edit counted as censored at the turn cap;
- usage deduplicated by message id, counting input, cache-creation and cache-read tokens;
- arms run concurrently, with the served model id recorded;
- an arm in which a coordinator writes the brief under the candidate skill text, because a hand-written
  list measures only an upper bound.

## 3. Dolt (`dolt-store`)

Dolt is a version-controlled SQL database that merges at cell level and reports conflicts per table. It is
the strongest database option considered, but:

- **Review.** Its data is not files in the tree, so a pull-request diff does not show changes to it, and
  decision records need review in the pull request.
- **Readability.** Agents cannot read its storage with plain-file tools.
- **Dependency.** It is a separate database binary, against no dependency for files in git.

**What would reopen it:** a work-state layer is built under §1, and file-per-record work state measurably
fails: sustained push contention, or a query the generated index cannot answer. Dolt is then the first
escalation, for the work-state layer only. Decision records stay files.
