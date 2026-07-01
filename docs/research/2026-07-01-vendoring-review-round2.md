# Vendoring mechanism — expert-review round 2, 2026-07-01

Second independent-expert-review panel over the mechanism **after** round 1's fixes landed. Fresh lenses:
threat-model red-team · simplicity/right-sizing · access-control & change-correctness · operational
resilience. Identical scope (current state, both repos), each reviewer blind to the desired conclusion.
Findings below are only those **re-verified against the code in the main loop**.

## Headline
The **simplicity reviewer passed it outright** (NITs only). Notably, the **threat-model reviewer's top
recommendation was to re-add per-skill sha256 hashes to the lockfile** — i.e. undo the pivot. Two
independent verdicts pointing opposite ways; we side with the pivot. Net yield: one real coupling bug, a
doc straggler missed in round 1, and a few robustness refinements.

## Carried (verified) + disposition

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| ① | MAJOR | `sync-agent-skills.sh:82-95` runs the ancestry check on **every** CI re-sync, including at the already-validated locked pin. If the hub renames its default branch / rewrites history so the pin is no longer an ancestor, every consumer PR goes red though the pin's bytes are identical. | **Proposed (approval — touches the now-`approval` sync script):** gate on `first_pin \|\| resolved_sha != locked_sha` (validate at bump time; skip on same-pin re-sync). |
| ② | MINOR | `.githooks/pre-push:12` still said `git diff --exit-code` (straggler missed in round 1). | **Fixed** → `git status --porcelain`. |
| ③ | MINOR | `access.yaml` glob precedence unspecified: `scripts/*.sh → approval` relies on "specific beats `**`", but `agent-access` SKILL.md:48-56 defines only per-path intersection and (:31-32) says the map is advisory. | **Proposed (approval — edits `access.yaml`):** add a one-line precedence note; ideally also upstream in the skill. |
| ④ | MINOR | `update-check.sh:33` exits 0 on hub-unreachable, so a sustained outage silently reads as "up to date" in the weekly job. | **Fixed** — `skills-update-check.yml` now emits a non-failing `::warning::` when the output shows an offline/registry-missing skip. |
| ⑤ | MINOR | Weekly job searched `--state open`, so a closed-but-unadopted tracking issue spawns a fresh duplicate each Monday. | **Fixed** — `--state all` + reopen-and-comment instead of re-filing. |
| ⑥ | NIT | `update-check.sh` had no explicit trailing `exit 0` (correct by fallthrough, brittle to edits). | **Fixed** (both repos) — explicit `exit 0`. |

**Options (deferred to user):** mark `scripts/update-check.sh` `approval` too (referenced by both
workflows, but advisory/low-blast); make the rollback guard fail *closed* when the old pin is absent from
history (currently warns+skips — acceptable for an accident-guard).

## Rejected on verification (did NOT survive)
- **"Re-add per-skill sha256 to the lockfile" (threat-model MAJOR)** — recreates the disconnected-hash
  design (finding A) the pivot removed; a hash stored beside the content it verifies adds nothing over
  git's own content-addressing. Simplicity reviewer independently confirmed the registry hashes are
  hub-only baggage. **Undoes the pivot — rejected.**
- **"Ancestry check lets an empty default-ref pass through" (threat-model MAJOR)** — misread;
  `sync-agent-skills.sh:89-94` explicitly **fails closed** (exit 2) on empty `def_ref`.
- **"origin/HEAD unresolved in a fresh Actions checkout" (operational BLOCKER)** — sync does its own full
  `git clone` of the hub (where `origin/HEAD` is set), not the Actions checkout. Real kernel captured as ①.
- **"SKILLS array mismatch (`end-of-round-report`)" (operational MAJOR)** — `SKILLS` is per-consumer by
  design; the skill exists at the pin (re-sync green with 7 skills). Not a defect.

## Passed clean
Simplicity: PASS. Panel-confirmed done-right: deterministic re-sync + `git status` gate, symlink hygiene,
canonical-hub assertion, atomic lockfile write, fail-closed first-pin ancestry, documented escape hatches.

## Verification performed
`bash -n` + shellcheck clean; hub update-check tests 7/7; workflow YAML parses; consumer scripts lint clean.
Non-contract fixes (②④⑤⑥) landed on `claude/agent-playbook-extraction-w0escf`; ① and ③ proposed for
approval.

---

## Round-3 correction (same day): finding ① was REVERTED

A round-3 adversarial panel re-examined finding ①'s implemented fix (gating the ancestry check on
`resolved_sha != locked_sha`) and found it was a **security regression**, independently reproduced and
verified mechanically in the main loop:

- In the **consumer CI re-sync** path `resolved_sha == locked_sha` always, so the gate skipped the
  ancestry check exactly there. A PR that hand-edits the lockfile `pinned_sha` to a hub commit **not on
  the default branch** (a full clone can check out an unmerged-branch commit) with matching vendored
  content would then leave `git status` clean and **pass CI** — where the unconditional check had
  blocked it (exit 2). Verified: `git checkout <unmerged-sha>` succeeds in a full clone and the commit
  is not an ancestor of the default branch.
- The coupling that motivated ① was **overstated**: a branch **rename preserves ancestry**, so it does
  not orphan a pin; only a rare hub **history-rewrite** does — which is worth failing on, not hiding.

**Disposition:** ① reverted in both repos (ancestry check is unconditional again), with a comment added
so it isn't re-broken. The two round-3 reviewers disagreed — a correctness/test reviewer passed the
change ("does what it intended, tests pass") while the security reviewer flagged the BLOCKER; agreement
is not validity, and no test covered the hand-edited-lockfile case. Findings ②–⑥ and the ③ precedence
note are unaffected and stand.
