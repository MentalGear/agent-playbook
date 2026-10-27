---
decides:
  - subject: decision-record-format
    outcome: adopted
    statement: Records in docs/decisions/ carry checked front matter, and a generated view lists the decision in force on each subject.
  - subject: hub-guide-relationship
    outcome: adopted
    statement: structured-repo-guide is the home for repository hygiene; the hub links to it at a pinned commit after an overlap inventory with a ruling per overlap.
supersedes: []
---
<!-- BEGIN GENERATED: scripts/decisions.sh. Do not edit; run scripts/decisions.sh --write. -->
> **Dated record: evidence, not instructions.** Current on: `decision-record-format` (adopted), `hub-guide-relationship` (adopted). Current decisions: [README.md](README.md).
<!-- END GENERATED -->


# Decision records the hub can check, and a pinned route to the guide

Review: `docs/research/2026-10-26-substrate-review.md` (adversarial board, runs 1 and 2). The
orchestration part of the same plan is `2026-10-27-orchestration-by-construction.md`.

The front matter above is the format this record adopts (§2).

## 1. The problem, observed in this hub

Decision records state things that are no longer true, and an agent that reads one can act on it. A
practitioner report on AI-maintained decision records says the same: "the same old problem of doc rot, but
now the docs are blindly obeyed" ([HN 50227041](https://news.ycombinator.com/item?id=50227041); one report,
not a study).

In this hub, the 7 records in `docs/decisions/` use 7 different free-text `Status` values, and 3 status
lines are stale:

- `2026-09-14-routing-index-evidence.md` says "open". Its amendment (line 46 onward) replaced the 26%
  figure with 22%, yet lines 79–81 still say "they are at 26% now" and that the first half of the kill
  criterion "is already true"; at 22% it is false.
- `2026-09-14-routing-index-prior-art.md` says "eval not built". The evaluation harness exists in
  `agent-playbook-test`.
- `2026-09-18-selection-tranche-1.md` says "one trigger change proposed". It shipped in `subagent-framework`
  1.4.0.

Supersession is marked only in prose (`routing-index-evidence.md` line 46, `routing-index-prior-art.md`
line 5).

## 2. Decision records (`decision-record-format`)

Scope: this hub's `docs/decisions/` only. Distribution to consuming repositories is a later decision (§4).

**Definitions.** The view, the banners and the check are all computed from these, and from nothing else.

- A **record** is a file `docs/decisions/YYYY-MM-DD-slug.md`. Its file name is its id. `README.md` is not a
  record.
- A record's front matter has `decides` (a list, possibly empty) and `supersedes` (a list of record file
  names, possibly empty). Each `decides` entry has `subject` (matching `^[a-z0-9-]+$`), `outcome` (`adopted`
  | `rejected` | `deferred` | `open`) and `statement` (one present-tense sentence, without the characters
  `|`, backtick, `<` or `>`, because it is copied into the view and banners). A record with an empty
  `decides` is a finding: a dated measurement or result.
- Record R **holds** subject X when R declares X and no other record that declares X lists R in
  `supersedes`. Every outcome holds a subject. A `rejected` record can supersede an `adopted` one, which is
  how a decision is retired without a replacement.

**What the check enforces.** It has a self-test that plants each of these violations and requires the
check to fail on each:

- Front matter is missing, has a duplicate key, or has a value outside the vocabulary above.
- A subject has two holders (an unlinked duplicate) or none (a `supersedes` cycle).
- A `supersedes` entry names a missing file, the record itself, or a record that shares no subject with it.
- A record still carries a free-text `**Status:**` line.
- The generated view or a generated banner is stale.
- Against the merge base, a merged record is deleted or renamed, its front matter changed, or its body
  changed other than by an appended section headed `## Amended YYYY-MM-DD`. CI checks out full history for
  this comparison.

**What is generated.**

- **A banner at the top of every record**, kept by the freshness check: "Dated record: evidence, not
  instructions", the subjects it holds, the subjects on which it is superseded and by which record, and a
  link to the view. An agent that opens a record by path sees it. CodeCompass found that a plain
  instruction left a tool unused in 58% of trials ([arXiv:2602.20048](https://arxiv.org/html/2602.20048v1),
  preprint, one model). This rule therefore sits where the record is read, not in a skill an agent must
  first load. In Claude Code the path-scoped rule `.claude/rules/decision-records.md` (`paths:
  docs/decisions/**`) also loads the rule into any agent's context the moment it reads or edits a record.
- **The view, `docs/decisions/README.md`**: the same rule in its header, then one row per subject (subject,
  outcome, statement, holder), sorted by subject. The guide puts its index at `docs/decisions.md`. The hub's
  records already live in `docs/decisions/`, so the index is that folder's README. One row per subject means
  two pull requests that claim the same subject edit the same line, and git reports a conflict. The view has
  no merge driver: GitHub's merges do not run custom drivers. A conflicted view is resolved by rebasing and
  regenerating.

**What it covers and what it does not** (guide principle 8):

- **Covered:** stale status lines, by removing them; unmarked supersession, which becomes a generated
  banner; two records in force on one subject; a merged record rewritten in place.
- **Not covered:** two subjects that mean the same thing under different names (the check is lexical; a new
  subject is a new row, visible in review); stale statements already in a record's body, which the
  migration corrects with `## Amended` sections; pending follow-up work, which is not a decision outcome and
  has no home in this hub.

**When a record conflicts with the code or with another record in force,** the agent reports the conflict
to a human and does not resolve it alone. A task whose purpose is to write a superseding record is exempt.

## 3. The hub and `structured-repo-guide` (`hub-guide-relationship`)

The guide is public and is the home for repository hygiene. The hub links to it at commit
`2b3d1f2a537674bbaeaea90f3c997bbb582afbdf` and does not copy it. Linking removes copies but does not
settle contradictions, so an inventory comes first:

- **Method.** Each of the 13 hub skills is compared with the guide's 9 principles and with the guide
  documents those principles cite. Each overlap is a row: the overlap, the guide and hub locations, the
  ruling, which side keeps the text, and whether an offline consumer needs the text in the hub. Skills are
  vendored into containers without network access, so text a consumer needs offline stays in the hub.
- **Already known.**
  - `docs/research/` is permanent in the hub (`agent-repo-layout` lines 26, 50–51) and archived once its
    item closes in the guide (`layout.md` lines 59, 69).
  - A decision's home: `agent-repo-layout` lines 95–96 and `agent-operating-principles` §6 put decisions in
    `docs/research/`, while this hub keeps them in `docs/decisions/`. Resolved in step 2:
    `agent-repo-layout` 1.4.0 defines `docs/decisions/`, and `scripts/test/layout-homes.test.sh` fails when
    a skill names, or this hub keeps, a `docs/` folder the layout does not define.
  - The guide's security rules for agents (`security/agents-and-automation.md`, rules 3 and 4) and this
    record's "evidence, not instructions".
- **Pin bumps** are reviewed by a human with the guide's diff in the pull request.

## 4. Acceptance and host settings

A record is in force when it is merged to the default branch. On another branch it is a proposal.

Who may merge is a host setting, and this hub does not enforce one. `main` has no branch protection, and
agents in this setup act under the owner's GitHub account, so a merge by an agent is indistinguishable from
the owner's. Until the owner changes that, "a model merges only on the owner's explicit instruction" is
policy, not enforcement. The owner's settings that would enforce it, recorded here and not done by an agent:

- a ruleset on `main` that requires a pull request and requires the decisions check, with "require
  branches to be up to date". This also closes the case where two pull requests, each valid alone, claim
  the same subject;
- agents acting under their own identity, without merge rights.

Until then, that case is caught by the check on `main` after the second merge. The fix is a new pull
request that supersedes one of the two records or renames its subject.

## 5. Rollout

Each step is one pull request, merged by the owner.

1. **Overlap inventory and pinned route (§3).** The inventory is a new decision record. Acceptance: every
   one of the 13 skills has at least one row or an explicit "no overlap", and every row has a ruling. Skills
   whose text is replaced by a pinned link get a version bump and a `CHANGELOG.md` entry, because they reach
   consumers.
2. **Decision records (§2).** The pull request description proposes the subject table for the 7 existing
   records (subjects, outcomes, statements, `supersedes`) for the owner to review. The change adds
   `scripts/decisions.sh`, its self-test, the CI step, front matter and banners on all records, and an
   `## Amended` correction for the stale lines in §1. No file is renamed. The format and its check stay in
   this hub. The only vendored change is the decision home in `agent-repo-layout` and
   `agent-operating-principles`, which fixes the contradiction in §3.
   - Revert criterion: on 2027-01-31 the owner reviews the check's CI failures since adoption. If none of
     them caught a real conflict or a stale record, and at least one forced a change the owner judged wrong,
     the check is removed and the front matter stays.
