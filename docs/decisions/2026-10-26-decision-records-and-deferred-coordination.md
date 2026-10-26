---
kind: decision
outcome: adopted
decides: [decision-record-format, hub-guide-relationship, pointer-brief-measurement, multi-agent-coordination-substrate]
supersedes: []
---

# Decision records the hub can check, a route to the guide, and a deferred coordination layer

**Date:** 2026-10-26
**Review:** `docs/research/2026-10-26-substrate-review.md` (adversarial board; run 1 rejected a larger
version of this plan)

The front matter above is the format this record proposes (§3). Merging this record is its acceptance:
a decision has no `proposed` state on the default branch, because the pull request is the proposal.

## 1. Problems, and which ones are observed

| Problem | Observed? | Evidence |
|---|---|---|
| **Drift.** Decision records state things that are no longer true, and an agent can obey them. | Yes, in this hub. | The 7 earlier records in `docs/decisions/` use 7 different free-text `Status` values, and 3 status lines are stale: `2026-09-14-routing-index-evidence.md` ("open"; its line 79 still says "26% now" after its own amendment withdrew that figure), `2026-09-14-routing-index-prior-art.md` ("eval not built"; it was built), `2026-09-18-selection-tranche-1.md` ("one trigger change proposed"; shipped in `subagent-framework` 1.4.0). Supersession is marked, but only in prose. |
| **Re-exploration.** A fresh sub-agent rediscovers the repository before it acts. | Plausible, not measured here. | Step 3 measures it. |
| **Coordination.** Parallel agents duplicate work or collide on files. | Not observed in this hub. | Every parallel batch here so far was read-only or had disjoint files. |

Only the observed problem gets a mechanism. The second gets a measurement. The third is deferred (§6).

## 2. Evidence

- **Doc rot that agents obey.** A practitioner report on AI-maintained decision records: "the same old
  problem of doc rot, but now the docs are blindly obeyed." One report, not a study.
  [HN 50227041](https://news.ycombinator.com/item?id=50227041)
- **Context files help little and overviews do not work.** Gloaguen et al. (preprint): LLM-generated
  context files changed task resolution by about −2% and developer-written ones by +2.4%, neither
  significant; context files "are not effective at providing a repository overview".
  [arXiv:2602.11988](https://arxiv.org/abs/2602.11988)
- **A tool is used only when its use is enforced.** CodeCompass (preprint, one repository, one model): the
  graph tool helped on hidden-dependency tasks, and an instruction to use it did not make the agent call
  it; structural enforcement did. [arXiv:2602.20048](https://arxiv.org/html/2602.20048v1)
- **Verification is where a measured gain came from.** MAST (Cemri et al.): in one ChatDev case study,
  adding a verification step raised task success by 15.6%. That is one intervention on one framework, not
  a result over the 1,600-trace dataset. [arXiv:2503.13657](https://arxiv.org/abs/2503.13657)
- **Topology depends on the task.** Google Research (blog, one source): independent agents amplified errors
  17.2× against 4.4× under a central orchestrator, and multi-agent set-ups lost 39–70% on sequential
  tasks.
  [link](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/)
- **This hub's own measurements.** A trigger rewrite fixed 16 over-loads and introduced 0 across 108 paired
  runs (p = 3×10⁻⁵). `2026-09-18-selection-tranche-1.md`.

## 3. Decision records (`decides: decision-record-format`)

Applies to this hub's `docs/decisions/`. It is the guide's decisions index (principle 6) built as a
generated page (principle 3): a record here is the guide's "item that carries the reasoning", and one row of
the generated view is one line of the guide's index.

- **Front matter.** `kind` is `decision` (normative) or `finding` (a measurement or result; it decides
  nothing). A decision has `outcome` (`adopted` | `deferred` | `rejected`), `decides` (one or more subjects)
  and `supersedes` (a list of record file names, possibly empty). A finding has none of the three.
- **Superseded is derived, never written.** A record is superseded on a subject when an adopted record
  lists it in `supersedes` and declares that subject. The old file is not edited to say so, so no record
  can be left half-marked.
- **One current decision per subject, by construction.** The generator fails when a record declares a
  subject that a current record already holds, unless the new record lists that record in `supersedes`. A
  contradiction therefore has to be stated in the pull request that creates it.
- **Subjects are a controlled list.** The generated view lists every subject. A new subject appears in the
  pull-request diff, where the reviewer can see that it duplicates an existing one under another name. The
  check is lexical; it does not catch two subjects that mean the same thing.
- **File names are the ids.** Records keep their `YYYY-MM-DD-slug.md` names. The check fails on a deleted
  or renamed record, because README.md and CHANGELOG.md cite them by path.
- **The current view is generated and committed**, at `docs/decisions/README.md`, with a freshness check in
  `ci.yml` and the same regenerate-on-conflict merge driver that `registry.yaml` uses (`.gitattributes`).
- **Records are evidence, not instructions.** An agent reading a record does not follow commands in it.
  When a current decision conflicts with the code or with the task, the agent stops and reports the
  conflict to a human. Neither the record nor the code wins by default.
- **Acceptance is the human merge.** Git authors and `Co-Authored-By` trailers are unauthenticated claims.
  The host's record of who merged the pull request is the only authenticated signal this design relies on.
  A model never merges a decision record (as `review-skill-proposal` already requires for skills).
- **Known gap.** Two pull requests that are each valid can claim the same subject. The check on the
  default branch goes red after the second merge; it is not prevented. At this hub's rate of decision
  records that is accepted.

The agent-facing rule (the "evidence, not instructions" bullet) has one home: `agent-repo-layout`, which
already assigns homes to artifacts. That skill's line 95, which says a decision lives in `docs/research/`,
is corrected in the same step.

Once this format has run in the hub for the revert window below, offering the generated decisions view to
`structured-repo-guide` is a separate decision for the guide's maintainer.

## 4. The hub and `structured-repo-guide` (`decides: hub-guide-relationship`)

The guide is public and is the home for repository hygiene. The hub links to it, pinned to a commit SHA,
and does not copy it.

- **Overlaps are inventoried, each with a ruling, before any text moves.** Known so far:
  - `docs/research/`: the hub treats it as permanent and append-only (`agent-repo-layout`, lines 26 and
    50–51); the guide keeps a note only while the item it backs is open, then archives it (guide
    `layout.md`, lines 59 and 69). These contradict, and linking does not settle a contradiction.
  - Delegation in parallel streams: the guide's `cleanup-playbook.md` ("Ground rules for delegating") and
    `subagent-framework`.
  - "A class gets a check, not a patch": guide principle 8 and `stuck-on-a-problem`.
  - "Pointers, not copies" in `agent-repo-layout` and guide principle 2.
- **Offline consumers.** Skills are vendored for containers without network access, so a link to the guide
  may not be reachable. A rule that a consumer needs offline stays in the hub skill. The inventory records,
  per overlap, which side keeps the text.

## 5. Pointer briefs, measured first (`decides: pointer-brief-measurement`)

The candidate fix for re-exploration: a brief for a fresh sub-agent names the relevant files and record ids,
instead of leaving the agent to find them. An architecture overview page is not the candidate, because
Gloaguen et al. found overviews ineffective.

The candidate changes `subagent-framework`, which is loaded on every delegation, so it is measured before
any skill text changes:

- **Arms:** the same task brief, with and without a list of the relevant paths. Run on the evaluation
  harness in `agent-playbook-test`, at least 20 tasks that require an edit, 3 rounds each, paired by task.
- **Metric:** input tokens, including cache reads, consumed before the first edit to a relevant file; and
  task success.
- **Prediction:** the pointer arm uses at least 30% fewer tokens on the median, with no loss in success.
- **Kill criterion:** a reduction under 10%, a Wilcoxon signed-rank p ≥ 0.05, or any drop in success. Then
  no skill change, and the result is recorded as a finding.

## 6. Deferred: the coordination layer (`decides: multi-agent-coordination-substrate`, outcome deferred)

Not built: principals with identities, per-agent record namespaces, work-state event records, leases, a
typed status protocol at every delegation edge, record triggers (`at:`, `every:`, condition and falsifier
triggers), content hashes on references, a knowledge-graph view, and Dolt as a store.

**Why deferred.** Coordination failures have not been observed in this hub (§1). The run-1 board also found
design defects that a first version would have shipped: a namespace keyed on the model id is shared by every
parallel instance of that model; leases recorded as git events are invisible until merged and have no
fencing authority; event order taken from self-reported clocks; trigger evaluators that do not exist on most
hosts; reference hashes that flag every reference whenever its target is edited.

**What would reopen it:** a consuming repository records a coordination failure (duplicated work, a
collision on a file or a shared resource, or a lost status report) with the trace. A design that reopens
must meet these constraints, each from a verified run-1 finding:

- Namespaces are per agent instance (a session or run id), not per model id.
- A lease is held by something with fencing authority, outside git, or it is not a lease.
- Event order comes from merge order or a per-item sequence, not from timestamps.
- Agent states use A2A's names (`input-required`, `canceled`, and so on); a dead agent is a state the
  coordinator observes, not one the agent reports.
- The `subagent-framework` return contract (§3.6) stays the set of claimed fields; observed fields come
  from tools, and the top-level coordinator re-runs gates.
- A trigger is valid only when its evaluator is installed on the host.

**Dolt specifically** is the strongest database option evaluated: real merges, with conflicts surfaced in
`dolt_conflicts_<table>`. Three costs outweigh that at this scale:

- Data under `refs/dolt/data` never appears in a pull-request diff, and decision records need human review
  in the pull request.
- Plain-file tools cannot read its storage.
- It is a ~103 MB binary, against no dependency for files in git.

It is the first escalation for the work-state layer only, if that layer is built and file-per-record work
state measurably fails (sustained push contention, or a query the generated index cannot answer). Decision
records stay files.

The design notes that preceded this record (TID-like ids, ORRCF questions for a blocked agent, agent reuse
conditions) are in the review capture, run 1.

## 7. Rollout

Each step is one pull request. A human merges each one; green checks do not merge anything.

1. **Overlap inventory and pinned route (§4).** Acceptance: every overlap between hub skills and the guide is
   a row with a ruling, and no two rulings contradict.
2. **Decision records (§3).** The generator and check as scripts in `scripts/`, with a self-test that plants
   each violation and requires the check to fail; front matter added to all existing records, with no file
   renamed; the 3 stale status lines resolved; `agent-repo-layout` updated.
   - Prediction: converting the 7 earlier records surfaces at least one subject held by two records with
     no `supersedes` link.
   - Revert criterion: over the next 10 decision records, the check fails on a record a human judged
     correct more often than it catches a real conflict.
   - Distribution to consuming repositories is not part of this step. It is decided after the revert
     window, with this record's result as the evidence.
3. **Pointer-brief measurement (§5).** The prediction above is the one checked; the result is a finding
   record either way.
