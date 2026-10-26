# Multi-agent substrate plan — adversarial board, 2026-10-26

Board on the multi-agent substrate plan, run under `independent-expert-review`. Five reviewers per run, one
lens each: distributed systems, security, multi-agent systems, feasibility and QA, docs-as-code. Identical
scope, read-only, fresh agents each run, strongest tier.

| Version | Where | Reviewed in |
|---|---|---|
| v1 | never merged; text in the appendix (commit `58d61ce`, no longer on a branch) | run 1 |
| v2 | commit `49228ce`, `docs/decisions/2026-10-26-decision-records-and-deferred-coordination.md` | run 2 |
| v3 | `docs/decisions/2026-10-26-decision-records-and-guide-route.md` and `docs/decisions/2026-10-26-deferred-coordination-layer.md` | run 3 |

**Pass rule, set before run 1:** a run is clean when no BLOCKER or MAJOR finding survives verification in
the main loop. The plan passes after 2 consecutive clean runs, each with fresh reviewers. Stop and report
after 4 runs without convergence.

## Run 1 — not clean

All five verdicts: unsound. Findings below were verified in the main loop against the files, `git log`, and
the cited papers. They are grouped by theme; the number of reviewers who raised each is a tiebreaker only.

| Theme | Sev | Raised by | Verified finding | Disposition in v2 |
|---|---|---|---|---|
| Measurement last | BLOCKER | multi-agent, feasibility | The rollout measured last and tested nothing it built; step 6 could not tell success from failure. The coordination problem was asserted, not observed. | v2 §1 classifies each problem as observed or not; only the observed one (drift) gets a mechanism; every step has a prediction and a revert or kill criterion (false for step 1, see run 2). |
| Merge on green | BLOCKER | security | "Merged when its checks are green" contradicts `review-skill-proposal` lines 14–19 (a model never self-accepts). | v2 §7: a human merges every step. |
| Identity | BLOCKER | security, distributed, docs-as-code, feasibility | Git author and trailers are unauthenticated. The proposing commit itself named the user as author for model-written work. A namespace keyed on the model id is shared by every parallel instance. | v2 §3: the human merge is the only authenticated signal relied on (false here, see run 2). The commit was re-authored. Namespaces deferred, with the per-instance constraint recorded. |
| Leases | BLOCKER | distributed, feasibility | A lease written as a git event is invisible until merged and has no fencing authority. | Deferred; constraint recorded in v2 §6. |
| Evidence misread | MAJOR | multi-agent, docs-as-code | (Partly wrong, see run 2.) Gloaguen: +2.4% (not significant), not "about 4%"; the overview finding was omitted and contradicts the plan's architecture page. CodeCompass: instruction did not make the agent use the tool; enforcement did. MAST +15.6% is one ChatDev case study. Google: the 39–70% loss on sequential tasks was omitted. | v2 §2 corrected; architecture page dropped from the candidate in §5. |
| Decision model vs guide | MAJOR | docs-as-code, multi-agent | Append-only records with a free-text `decides:` conflicted with the guide's decisions index and with the hub's own in-place amendments; no `proposed → accepted` path without an edit; one subject per record did not fit multi-decision records. | v2 §3: superseded status is derived, merge is acceptance, several subjects per record, controlled subject list, mapping to guide principles 3 and 6 stated. Strict append-only dropped. |
| "Code wins" | MAJOR | security, multi-agent, docs-as-code, feasibility | Undefined for non-code decisions; lets a regression override a decision silently. | v2 §3: stop and report the conflict to a human. |
| Records as an injection channel | MAJOR | security | Agent-written records read by later agents carry instructions. | v2 §3: records are evidence, not instructions. |
| Plan broke its own rule | MAJOR | docs-as-code | The same commit appended the Dolt deferral to an existing record. | `2026-09-13-deferred-agent-mechanisms.md` restored; Dolt lives in v2 §6. |
| Overlaps with the guide | MAJOR | docs-as-code, feasibility | The guide already covers several writers (`cleanup-playbook.md`, "Ground rules for delegating"); hub and guide contradict on `docs/research/`; "resolve by pointing" settles copies, not contradictions; `agent-repo-layout` line 95 gives decisions a third home. | v2 §4 inventory with a ruling per overlap; line 95 corrected in step 2. |
| Unpinned, unreachable route | MAJOR | security, docs-as-code | Vendored skills run offline; the guide has no tag. | v2 §4: pinned SHA; offline-needed rules stay in the hub. |
| Checks cannot reach consumers | MAJOR | docs-as-code, feasibility | Only skills and the sync script are distributed; `ci.yml` has no link or reference check. | v2 §3 applies to the hub only; distribution decided after the revert window. |
| Generated views in parallel work | MAJOR | distributed, docs-as-code | A committed view conflicts on every parallel merge; a gitignored one hides changes from review. | Committed, with the `registry.yaml` regenerate-on-conflict driver (wrong, see run 2). |
| Checks across pull requests | MAJOR | distributed | Two valid pull requests can together violate a uniqueness check; `ci.yml` has no `merge_group`. | Recorded as a known gap in v2 §3. |
| Protocol | MAJOR | multi-agent, docs-as-code, feasibility | `blocked` is not an A2A state, `canceled` missing, dead agents unrepresentable; claimed fields dropped the §3.6 return contract; observed fields collapse under recursion; duplicates the delegation log; the debate exception breaks panel independence. | Protocol deferred; constraints recorded in v2 §6. |
| Triggers, reference hashes, work-state log | MAJOR | all five | Evaluators absent on most hosts; idempotency races; hashes flag every edited target; event order from self-reported clocks; "a log cannot drift" is false when an agent dies after claiming. | Deferred; constraints recorded in v2 §6. |
| Overstated claim | MINOR | docs-as-code | "Nothing marks as superseded" is false; markers exist, in prose and inconsistently. | v2 §1 restated with the 3 stale status lines. |
| Unsourced figure | MINOR | docs-as-code, feasibility | "Cache lifetime one hour" had no recorded measurement and is host-specific. | Removed with the reuse conditions. |
| Miscount | NIT | multi-agent | "16 paired runs": 108 paired runs, 16 fixed. | Corrected. |

**Rejected on verification:** none outright. Two reviewers disagreed on MAST (one "checks out", one
"misread"); both hold: the figure is real and its scope was overstated.

**What the reviewers credited:** evidence graded by strength; derived views never authoritative; claimed
and observed fields separated; heartbeats kept out of git; the Dolt deferral with a reopen condition; the
candid open-risk list; the repository-internal figures, which checked out.

## Run 2 (v2) — not clean

Verdicts: security and feasibility unsound or blocked; distributed systems, multi-agent and docs-as-code
sound with fixes. Verified in the main loop: the merge-driver failure was reproduced in a scratch clone;
CodeCompass and MAST were re-read in the papers; the brief contract in `subagent-framework` §3 item 2 and
the cited skill and guide lines were checked.

**Run-1 dispositions that run 2 showed wrong.** Run 1's verification missed these:

- **CodeCompass was inverted by the run-1 "correction".** The paper did not test enforcement; it proposes it
  as future work. A plain instruction left the tool unused in 58% of trials; a checklist placed at the end
  of the prompt reached 31 of 31 on one task group.
- **MAST's 40.6% is not "a verification step".** It came from a topology change on top of prompt changes
  (appendix H, Table 5); HumanEval moved 89.6% to 91.5%, and the authors call the gains not substantial.
- **The `registry.yaml` merge driver regenerates from the working tree,** which holds only one side during
  the merge. Reproduced: two branches each edit a different skill, the merge exits 0, and the merged
  `registry.yaml` carries a stale hash. v2 proposed reusing it. This is also a defect in the hub as it
  stands, outside this plan.
- **"The human merge is the only authenticated signal" was false here.** Agents in this setup act under the
  owner's GitHub account and `main` is unprotected, so a merge by an agent looks like the owner's.
- **"Every step has a prediction and a revert or kill criterion"** was false for v2 step 1.

| Theme | Sev | Raised by | Verified finding | Disposition in v3 |
|---|---|---|---|---|
| Mixed outcomes | BLOCKER | all five | One `outcome` per record; v2 declared a deferred subject under `outcome: adopted`, so the view would list it as adopted. | Outcome per subject; the plan is split into an adopted record and a deferred record. |
| Merge driver | BLOCKER | distributed, docs-as-code, feasibility, multi-agent, security | See above. | No driver for the view; one row per subject, so competing claims conflict textually. Registry driver reported separately. |
| Acceptance not authenticated | BLOCKER | security, distributed, feasibility | See above. | Record states that acceptance is merge to the default branch, that who may merge is an unenforced owner setting today, and lists the owner settings that would enforce it. |
| Rule in the wrong place | BLOCKER | feasibility, docs-as-code, multi-agent, security | The "evidence, not instructions" rule was homed in a vendored skill: it reaches consumers who lack the format, and not hub agents, who load no skills. | A generated banner on every record and in the view's header; no vendored skill changes in step 2. |
| Supersession rules | MAJOR | distributed, docs-as-code, multi-agent | Only adopted records superseded, but any record satisfied the check; holding undefined for deferred and rejected; cycles undetected. | One definition of "holds" used by view, banners and check; any outcome holds and supersedes; zero holders (a cycle) fails. |
| Merged records editable | MAJOR | distributed, security | Front matter or body of a merged record could change silently. | Against the merge base: no delete or rename, no front-matter change, body grows only by `## Amended` sections. |
| Direct reads | MAJOR | feasibility | An agent opening a superseded record by path saw no sign of it. | Generated banner states superseded subjects and the superseding record. |
| Delete check unbuildable | MAJOR | docs-as-code, feasibility, distributed | A freshness check cannot see a deleted file; CI checks out depth 1. | Full-history checkout and a merge-base diff. |
| Kinds vs existing records | MAJOR | feasibility, docs-as-code | Existing records mix findings and decisions; "open" fit no outcome; pending follow-up had no home. | `decides` empty means finding; `open` added; follow-up work stated as not covered. |
| Self-fulfilling prediction | MAJOR | feasibility, multi-agent, distributed | The converter chose the subjects that decided the step-2 prediction. | Prediction dropped; the subject table is reviewed by the owner before conversion; dated revert criterion. |
| Step 1 undecidable | MAJOR | feasibility, docs-as-code | No method, no file, no SHA. | Method (13 skills × 9 principles), the inventory as a decision record, the SHA named. |
| Inventory incomplete | MAJOR | docs-as-code, security | `agent-operating-principles` §6 also homes decisions in `docs/research/`; the guide's security rules 3 and 4 overlap. | Added to the known overlaps. |
| §5 measurement | MAJOR | multi-agent, feasibility | The harness has 6–8-file fixtures, tasks name files, no test oracle, workspace deleted; the candidate already exists in `subagent-framework` §3 item 2 except record ids; undefined zone between kill and prediction; oracle pointers measure an upper bound. | Deferred, with the task bank as the reopen condition and the design requirements listed. |
| Deferral premise | MINOR | multi-agent | "Not observed" while the hub keeps no delegation log. | Restated as not recorded and not instrumented; reopen accepts hub-side reports; review date set. |
| Deferred constraints | MINOR | distributed, multi-agent | Session id is not per-instance; leases need compare-and-swap plus fencing at the resource, not "outside git"; sequence numbers collide; dead agents need fencing; missing trigger, hash and panel constraints. | Constraints rewritten. |
| Evidence detail | MINOR | multi-agent, docs-as-code | Gloaguen's cost increase omitted; Google's paper uncited; Dolt figures unsourced. | Added; unsourced Dolt numbers removed. |

**Rejected on verification:** none.

## Appendix — plan v1 as reviewed in run 1

> # A substrate for multi-agent work: principals, records, protocol, triggers
> 
> **Date:** 2026-10-26
> **Status:** proposed — under adversarial review
> **Scope:** the hub (`agent-playbook`) and its relationship to `structured-repo-guide`
> **Deferred alternatives:** `2026-09-13-deferred-agent-mechanisms.md` (§2 sub-agent messaging, §3 Dolt)
> 
> ## 1. The problems
> 
> Three problems, each observed in this hub's own work or in the cited evidence:
> 
> 1. **Coordination.** Several agents — human or model — work in one repository at the same time. They
>    duplicate work, collide on files and shared resources, and report status as free prose that the
>    coordinator cannot check.
> 2. **Re-exploration.** A freshly spawned sub-agent rediscovers the repository before it can act. That costs
>    tokens, and what it learns is lost when it exits.
> 3. **Drift.** Rationale, decisions and status written as prose go stale and contradict the code. Agents then
>    obey the stale text.
> 
> ## 2. Evidence this plan rests on
> 
> Each item names its source and its strength. Vendor and preprint results are marked.
> 
> - **Verification beats message format.** In the MAST taxonomy (Cemri et al., 2025, 1,600+ traces, 7
>   frameworks), the largest measured intervention gain was adding a verification step (+15.6%). No controlled
>   study found shows that a typed message protocol by itself reduces multi-agent failures.
>   [arXiv:2503.13657](https://arxiv.org/abs/2503.13657)
> - **Central coordination beats peer meshes.** Independent agents amplified errors 17.2× against 4.4× with a
>   central orchestrator (Google Research blog — a single source).
>   [link](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/)
> - **Results by reference.** Anthropic's research system has sub-agents write output to storage and return
>   references (vendor engineering post).
>   [link](https://www.anthropic.com/engineering/multi-agent-research-system)
> - **Generated context files hurt.** LLM-generated `AGENTS.md`-style files lowered task resolution and added
>   about 20% cost; human-written ones gained about 4% (Gloaguen et al., preprint).
>   [arXiv:2602.11988](https://arxiv.org/abs/2602.11988)
> - **A code index is used only when pointed at.** In CodeCompass (one repo, one model, preprint), a graph
>   tool helped on hidden-dependency tasks, lost on others, and was never called in 58% of trials.
>   [arXiv:2602.20048](https://arxiv.org/html/2602.20048v1)
> - **AI-maintained decision records degrade agents at scale** — one practitioner report, not a study:
>   "the same old problem of doc rot, but now the docs are blindly obeyed."
>   [HN 50227041](https://news.ycombinator.com/item?id=50227041)
> - **CRDTs converge without preserving invariants.** Two valid concurrent updates can merge into an invalid
>   state (Kleppmann, CACM). [PDF](https://martin.kleppmann.com/papers/convergence-cacm.pdf)
> - **This hub's own measurements.** The playbook changed agent behaviour on 3 of 19 items with 1 loss
>   (diagnostic, not significant); a single trigger rewrite cut skill over-loading in 16 paired runs with 0
>   regressions (p = 3×10⁻⁵). `docs/decisions/2026-09-18-*.md`.
> 
> ## 3. Relationship to `structured-repo-guide`
> 
> `MentalGear/structured-repo-guide` is public and is the **home** for repository hygiene: current-state docs
> and comments, history-in-comments with its scanner, the tracker as files with generated indexes, generated
> docs with freshness checks, ratchets, and one gate runner. Its mechanisms have self-tests and are measured.
> 
> - **The hub does not copy it.** A hub skill routes to it: when the situation is "docs or comments drift from
>   the code", the route points at the guide.
> - **Overlap is resolved by pointing.** Where a hub skill restates a guide principle (for example "a class
>   gets a check, not a patch" in `stuck-on-a-problem`), one of the two becomes a link. Which side keeps the
>   text is decided per rule, by which audience needs it in full.
> - **The hub adds only the multi-agent layer** below (§4–§11), which the guide does not cover.
> 
> ## 4. Principals
> 
> A **principal** is anyone who acts: a human or a model. All principals use the same records and protocol.
> 
> - **Identity fields:** `kind` (human | model), `id`, and `on_behalf_of` (the principal accountable for a
>   model's action). Every action therefore resolves to an accountable human.
> - **A model is identified by its exact model ID**, never an alias. An alias can silently change the model it
>   serves; this hub observed that between two evaluation runs.
> - **Authority sits on state transitions, not on the interface.** Some transitions require a human principal:
>   accepting a decision, merging a skill into the hub, approving a permission. The protocol states which.
> - **Transport is a host slot.** In git the existing channel is the commit author plus `Co-Authored-By`
>   trailers. Another host may use DIDs or platform accounts.
> 
> ## 5. Records
> 
> Every durable fact that cannot be derived from the code is a **record**: one file, in git.
> 
> - **One file per record, author-namespaced:** `records/<principal>/<kind>/<id>.md`. A principal only creates
>   files in its own namespace, so two principals never write the same file.
> - **Ids are generated without coordination:** a sortable timestamp id (as in AT Protocol TIDs) within the
>   author's namespace. The full id is `<principal>/<id>`, so parallel agents cannot collide. This closes the
>   id-collision case of "highest id plus one" under parallel work.
> - **Human-readable citation stays available** through a short alias in the generated index; the alias is
>   derived, never the key.
> - **Kinds:** `decision`, `item` (work), `event` (a state transition), `finding`. Each kind has a front-matter
>   schema, validated in CI.
> - **References** name a path, a symbol or a record id, optionally with a content hash of the target. A
>   reference whose target is gone fails the link check. A reference whose hash no longer matches is flagged
>   for review — the guide's staleness marker, as a property of every reference.
> - **Derived views** (indexes, the current-state view, the graph) are generated from records, gitignored or
>   freshness-checked, and never authoritative.
> 
> **Relationship to the guide's tracker.** The guide's tracker (`docs/backlog/NNN-slug.md`, sequential ids)
> remains correct for a single writer. A repository with parallel agents uses the namespaced form. Reconciling
> the two is the first open question (§12).
> 
> ## 6. Work state
> 
> - **A state change is a new `event` record**, not an edit: `{item, state, at, by, evidence}`. Nothing is
>   mutated, so nothing conflicts, and history needs no extra mechanism. The current state of an item is the
>   latest event, computed in a derived view.
> - **Durable transitions go in git; heartbeats do not.** Claimed, blocked, completed, failed, with their
>   evidence, are events. Liveness signals stay in the harness or an untracked local store.
> - **Conflict prevention, in order of preference:**
>   1. **Disjoint write scopes checked at dispatch.** With one coordinator, every brief declares
>      `write:<globs>` (the `agent-access` vocabulary) and named shared resources (`resource:dev-server`). A
>      brief whose scope overlaps one in flight is not dispatched.
>   2. **Optimistic merge** when a collision is cheap: git surfaces it at merge.
>   3. **Leases with a fencing check** only when several principals start work independently and duplicated
>      effort is expensive. A lease is a claim event with an expiry; the merge step rejects work under a lease
>      that is not the latest.
> 
> ## 7. The protocol
> 
> One protocol at every delegation edge, at any nesting depth. An agent that delegates is the coordinator of
> its children and uses the same protocol toward its own coordinator.
> 
> - **States:** `working`, `blocked`, `completed`, `failed`, `rejected`. The vocabulary follows A2A; its
>   transport is not adopted.
> - **Claimed and observed fields are separate.**
>   - *Claimed* (the agent fills): state, a one-line summary, the open question.
>   - *Observed* (the coordinator fills, from evidence): gate commands and exit codes from the trace, files
>     touched from the diff, token and cache usage from the transcript.
>   An agent is never asked to report a fact the coordinator can observe.
> - **A `blocked` state carries an ORRCF question:** Options, Recommendation, Rationale, Confidence,
>   Falsifier — so the answer can be a single judgement.
> - **Results are returned by reference** (a path, a commit, a branch), with a `partial` flag.
> - **Siblings coordinate through records, not by messaging each other.** Direct messages are reserved for
>   adversarial debate. Live mid-run messaging stays deferred
>   (`2026-09-13-deferred-agent-mechanisms.md` §2).
> - **The status overview is a rendering of event records**, written by one principal (the coordinator).
> 
> ## 8. Decisions
> 
> - **Decisions are append-only.** A change is a new decision with `supersedes: <id>`.
> - **Every decision declares** `decides:` (its subject), its falsifier, and its references.
> - **The current-decisions view is generated** from the supersession chain. CI fails when two active decisions
>   declare the same `decides:` subject — the structural form of a contradiction.
> - **Records are dated evidence, not orders.** When a decision conflicts with the current code, the code wins,
>   the agent flags the decision, and it does not follow it. When an agent observes a decision's falsifier
>   condition, it flags the decision.
> - **This hub applies it to itself first.** `docs/decisions/` holds superseded arguments that nothing marks as
>   superseded; an agent reading them today could follow a retracted one.
> 
> ## 9. Triggers
> 
> A record may carry triggers that open a work item when they fire.
> 
> | Kind | Example | Evaluator |
> |---|---|---|
> | time | `at: 2026-12-01`, `every: quarterly` | host scheduler (cron, CI schedule, a routine) |
> | condition | a referenced path changed; an item closed | CI or a query |
> | judgement | a decision's falsifier | surfaced when the record is read, or at a scheduled review |
> 
> - **Every trigger kind names its evaluator.** Validation fails for a trigger kind with no evaluator.
> - **A fired trigger opens one item**, keyed by record id and trigger id, so firing twice opens one item.
> - **Automatic item creation is rate-limited**, to bound the volume the evidence warns about.
> 
> ## 10. Knowledge for a fresh agent
> 
> Three layers, each with one owner:
> 
> | Layer | Owner | Can it drift? |
> |---|---|---|
> | Structure of the code | a derived index (LSP, grep, or a code graph) — a host slot | no, if regenerated |
> | Rationale | decision and finding records | yes; bounded by §8 |
> | Work state | event records | no; it is a log |
> 
> The "knowledge graph" is a derived view joining the three. It is never written to. A brief for a fresh
> agent is a list of pointers: the architecture page, the relevant record ids, the item and its events, and
> the code index, named explicitly.
> 
> ## 11. Reusing agents
> 
> Give a follow-up task to an existing agent instead of a fresh one when all of these hold:
> 
> - the task is in the same area;
> - its cache is still warm (the observed cache lifetime is one hour);
> - its working tree is current with what others merged;
> - the task is not a review or verification of its own work;
> - its context is not close to compaction.
> 
> Otherwise spawn a fresh agent with a pointer brief (§10).
> 
> ## 12. Open questions and risks
> 
> 1. **Two id schemes.** Sequential ids in the guide and namespaced ids here. Unify, or define when each
>    applies.
> 2. **The protocol's value is unproven.** It is justified by making verification cheap, not by a measured
>    reduction in failures. If verification can be made cheap without it, it should shrink.
> 3. **Record volume.** AI-written records are the failure mode in the evidence. Limits: only facts that
>    cannot be derived; a human ruling turns a question into a decision; supersession is enforced.
> 4. **Weight for a project-agnostic hub.** Every mechanism here must work with plain files, git and a shell,
>    and degrade to "not adopted" without breaking the rest.
> 
> ## 13. Rollout
> 
> Each step is one PR, merged when its checks are green.
> 
> 1. Route the hub to the guide; resolve overlaps by pointing (§3).
> 2. Apply §8 to this hub's own `docs/decisions/`: front matter, supersession, a generated current view.
> 3. Record schemas, the namespaced layout and the reference check (§5).
> 4. Protocol fields and states in `subagent-framework` (§7, §11).
> 5. Triggers (§9).
> 6. Measure: tokens spent before the first relevant edit, with and without an architecture page and a code
>    index, on the evaluation harness; the prediction is recorded before the run.
