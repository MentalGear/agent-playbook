---
name: propose-skill
description: Use when you have a reusable, project-agnostic skill (or a fix to an existing one) and want to contribute it back to the shared hub (MentalGear/agent-playbook) so other repos can vendor it. Defines the standard contribution format (the skill directory + required frontmatter + a registry bump) and the steps to propose it as a PR that the hub validates with review-skill-proposal. Project-specific skills stay in your repo; only generalizable ones get published.
user-invocable: false
version: 1.0.0
requires: [review-skill-proposal]
---

# Propose a skill to the hub

How to contribute a new skill — or an update — **back to `MentalGear/agent-playbook`** (the hub), in the
standard format the hub can validate and other repos can vendor. Publish only **project-agnostic** skills;
keep project-specific guidance in your own repo (it has no home in a shared hub).

> **Target hub:** `MentalGear/agent-playbook`. The "envelope" is simply a PR that adds the skill directory +
> a regenerated `registry.yaml` — no tarball or signing. The hub validates it with the **review-skill-proposal**
> skill before merging.

## What a publishable skill must have
- A directory `skills/<name>/` with **`SKILL.md`** (and any `reference.md`/assets it needs).
- **Frontmatter** (the contract `review-skill-proposal` checks):
  - `name:` — matches the directory.
  - `description:` — triggers-first, concrete (what it is + when to load it).
  - `version:` — semver; start a **new** skill at `1.0.0`, **bump** an existing one (patch for wording,
    minor for added guidance, major for a breaking reshape).
  - `requires:` *(optional)* — other skills it depends on (must exist in the hub).
  - `default-access:` / `isolation:` *(optional)* — declare per the **agent-access** skill if the skill
    spawns sub-agents; a non-`read-only` default needs maintainer sign-off.
- It must be **parameterized, not project-specific**: gates/paths/commands belong in the consuming repo's
  slots (see `project-gates` / `agent-repo-layout`), not hardcoded in the skill.

## Steps to propose
1. **Author** `skills/<name>/SKILL.md` with the frontmatter above. Run it past the **independent-expert-review**
   skill if it's non-trivial.
2. **Regenerate the index:** `scripts/build-registry.sh`, and commit the updated `registry.yaml`.
3. **Self-validate** (run the receiver's check yourself first): `scripts/validate-skill.sh <name>` — fix every
   ✗ before proposing.
4. **Open a PR** to `MentalGear/agent-playbook` adding the skill dir + the registry bump. Describe what it's
   for, why it's general, and which existing skills it interlocks with.
5. On merge, downstream consumers see it via their **update-check** (new skill in the registry) and vendor
   it deliberately.

## Updating an existing skill
Same flow, but **bump `version`** and say what changed (and whether it's breaking) in the PR — that's what
makes a consumer's update notification actionable. Never change a skill's behaviour without a version bump.
