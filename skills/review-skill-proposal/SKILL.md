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

> **Parameterized:** the allowed access vocabulary is the **agent-access** scope set; "general enough to
> publish" is judged against this hub's scope (project-agnostic method skills only).

## Mechanical check — run the validator
```
scripts/validate-skill.sh <name>      # or --all
```
It **rejects** (non-zero) on any of:
- missing/!=dir `name`, missing/short `description`, non-semver `version`;
- `requires:` naming a skill that doesn't exist here;
- `default-access`/`isolation` outside the known vocabulary;
- `registry.yaml` stale (not regenerated) or missing this skill's content hash.

It **warns** (but doesn't reject) when a skill declares a **write** `default-access` — that needs explicit
maintainer sign-off (a contributed skill shouldn't silently grant itself write by default).

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
