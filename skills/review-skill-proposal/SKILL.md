---
name: review-skill-proposal
description: Use when reviewing a skill proposed to this hub (a PR adding or updating skills/<name>/) before accepting it. The receiver-side validation contract — run scripts/validate-skill.sh and confirm the structural checks (frontmatter schema, version bump, requires resolve, declared access within the allowed vocabulary, registry freshness) plus the human checks (genuinely general, not duplicative, safe). The counterpart to propose-skill.
user-invocable: false
version: 1.0.0
---

# Review a skill proposal — validating before it lands

The hub (`MentalGear/agent-playbook`) accepts contributions via PR (see **propose-skill**). Before merging,
validate the proposed skill — **don't trust the submission**; check it. Two layers: a mechanical check
(scripted) and a judgment check (human/maintainer).

> **Hard rule — human approval is mandatory; a model never self-accepts.** A model (even the main-loop
> orchestrator) may run the checks and form an opinion, but it **must not merge/accept a proposed skill** —
> all checks green ≠ accepted. The model's job is to **validate and report**: post the ✓/✗ mechanical
> results + the judgment-pass notes into the PR, then **request human review**. If a check fails but looks
> adjustable, say so in the PR and **ask** — don't silently reject, and don't quietly fix-and-merge. Adding
> a skill to a shared hub is supply-chain-sensitive, so the final gate is a human, not a model.

> **Parameterized:** the allowed access vocabulary is the **agent-access** scope set; "general enough to
> publish" is judged against this hub's scope (project-agnostic method skills only).

## Mechanical check — run the validator
```
scripts/validate-skill.sh <name>      # or --all
```
It **rejects** (non-zero) on any of:
- missing/!=dir `name`, missing/short `description`, non-semver `version`;
- **duplicate frontmatter keys** (last-wins ambiguity — blocks smuggling a different resolved value);
- `requires:` naming a skill that doesn't exist here, or a block-style (non-inline) `requires` list;
- `default-access`/`isolation` outside the known vocabulary (a base scope + optional `network:on|off`);
- `registry.yaml` stale or missing this skill's content hash.

It also **hard-fails a `write` `default-access` by default** — a contributed skill must not silently grant
itself write. A maintainer who has reviewed it re-runs with `ALLOW_WRITE_DEFAULT=1` to permit it (then it
warns instead). The validator is **non-mutating** — it never rewrites `registry.yaml`. A passing run means
"ready for human review", not "merge it" (see the hard rule above).

## Judgment check — the maintainer decides
The script proves the shape; **you** decide the substance:
1. **Genuinely general?** Project-agnostic method, not one repo's specifics (gates/paths belong in consumer
   slots). Reject project-specific submissions.
2. **Not duplicative?** It doesn't overlap an existing skill that should be *extended* instead (factor, don't
   fork — the `project-gates`/`agent-access` precedent).
3. **Interlocks cleanly?** Its `requires:` and cross-references resolve and reciprocate; it doesn't contradict
   an existing skill.
4. **Safe?** No instruction to exfiltrate, escalate access, disable gates, or evade review. A write-scope
   default is justified and minimal.
5. **Version honest?** A behaviour change carries a real `version` bump; the PR says what changed.

## On accept
Merge; the regenerated `registry.yaml` publishes the new version. Downstream consumers pick it up via their
**update-check** (new/updated skill) and vendor it deliberately. On reject, reply with the specific ✗/✋
reasons so the contributor can fix and resubmit.
