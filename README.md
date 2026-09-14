# agent-playbook [PUBLIC]

Reusable, **project-agnostic** working method for coding agents (Claude Code and friends), packaged as
load-on-demand **skills**. Extracted so the method can be shared across repos while each consuming repo keeps
only its project-specific rules and concrete gate values.

## What's here

```
skills/
  subagent-framework/
    SKILL.md                            # delegate to subagents & keep the judgment: when to delegate,
                                        #   the task contract, roles, orchestration patterns, guardrails
    reference.md                        #   reference detail: the eval scorecard, two-tier logging, tooling
  agent-operating-principles/SKILL.md   # research-first (3 reuse questions, boundary triggers) ·
                                        #   the troubleshooting playbook · keep-the-troubleshooting-doc
                                        #   -current discipline · test real code, commit load-bearing
                                        #   spikes as evidence · pre-commit decision criteria
  solve-by-construction/SKILL.md        # eliminate the failure mode instead of guarding it: the loop
                                        #   (deconstruct → construct → check prior art), the rung ladder,
                                        #   the elegance test, sweep once an invariant lands
  verification-instruments/SKILL.md     # keeping evidence honest: probe before filing · formalise as the
                                        #   cheapest oracle · foreign vectors · mutation-check the fix in
                                        #   an isolated worktree · benchmarks as committed instruments
  salvage-subagent-transcript/SKILL.md  # a subagent went stale/crashed/returned junk: harvest the
                                        #   workspace diff + transcript, then resume / harvest / discard
  independent-expert-review/SKILL.md    # neutral multi-discipline review panels: sizing, the reviewer
                                        #   contract, finding schema, synthesis + per-finding verification
  project-gates/SKILL.md                # the gate-manifest schema (categories, triggers, flow) that
                                        #   subagent-framework + independent-expert-review reference
  agent-repo-layout/SKILL.md            # standard .agents/ + docs/ layout, the path→permission map
                                        #   (.agents/access.yaml), scratch-is-throwaway-only (load-bearing
                                        #   spikes get committed), and the ship-a-working-devcontainer convention
  agent-access/SKILL.md                 # access-scope vocabulary (read-only/propose/write:<globs>/write) +
                                        #   isolation (inline vs sub-agent); resolves against access.yaml
  propose-skill/SKILL.md                # how to contribute a skill back to this hub (format + steps)
  review-skill-proposal/SKILL.md        # receiver-side validation contract for a proposed skill
  end-of-round-report/SKILL.md          # how to hand back a round's conclusion (rule + heading; outcome-first)
  stuck-on-a-problem/SKILL.md           # on the SECOND instance of a defect shape, enumerate the class,
                                        #   fix all, guard it; step up a level instead of patching again
standing-rules.md                       # curated always-loaded rules (verbatim, no skill names) — the
                                        #   "## Standing rules" half of the generated AGENT_RULES.md
CHANGELOG.md                            # consumer-facing changes; ACTION REQUIRED entries are the
                                        #   upgrade channel that reaches a stale vendored script
registry.yaml                           # published index (generated; per-skill version, sha256, requires, …)
scripts/
  lib.sh                                # shared helpers (require_tools, jq lockfile readers, skill_dir_hash)
  sync-agent-skills.sh                  # canonical vendoring tool — DETERMINISTIC (copy into your repo)
  build-registry.sh                     # regenerate registry.yaml from skill frontmatter
  validate-skill.sh                     # validate a proposed skill (used by review-skill-proposal)
  update-check.sh                       # consumer: lockfile vs upstream registry (new/updated/deprecated)
  measure-index-overhead.sh             # instrument: is the route index earning its always-loaded context?
  setup.sh                              # one-time: register the registry.yaml regenerate-on-conflict driver
.github/workflows/ci.yml                # registry freshness · validate-skill · test harnesses · shellcheck
VERSION                                 # the human-facing release ref (consumers also pin a commit SHA)
```

The skills interlock: **subagent-framework** is the delegation contract, **independent-expert-review** is the
review-panel pattern it references, **project-gates** is the shared gate-manifest schema both of them point
at, **salvage-subagent-transcript** is what you reach for when a delegation dies, **agent-repo-layout** is
the standard repo structure + permission map, **agent-access** is the scope/isolation vocabulary delegations
declare (resolving against that map), **solve-by-construction** and **verification-instruments** are the
fix-it-at-the-right-layer and prove-it-actually-holds halves of landing a change, and
**agent-operating-principles** is the cross-cutting working discipline. A skill folder may carry
extra files beyond `SKILL.md` (e.g. `subagent-framework/reference.md`), so vendor the **whole skill
directory**, not just the entry file.

All skills are deliberately parameterized: they define the *slots* (which gates to run, where the logs and
docs live), and the **consuming repo supplies the values** — its gates in a `project-gates` manifest, the
rest typically in its `CLAUDE.md`. Get that seam right and a skill drops into a non-Svelte, non-JS repo with
only its slot values changed (the gate categories are an open list — UI a11y/visual-regression are
*examples* of the safety-specific category, not required gates).

> The canonical pin is the **commit SHA** recorded in each vendored copy (see [Versioning](#versioning));
> `VERSION` is a human-facing label.

## How to vendor it into a consuming repo

These skills are meant to be **vendored** (copied in + pinned), not submoduled — the proven pattern for
ephemeral fresh-clone web/sandbox containers, no submodule-init or egress-proxy friction.

**Use the provided sync script — don't hand-copy.** [`scripts/sync-agent-skills.sh`](scripts/sync-agent-skills.sh)
is the canonical vendoring tool; copying files by hand drifts and loses the pin. Steps:

1. **Copy `scripts/sync-agent-skills.sh` + `scripts/lib.sh`** into your repo's `scripts/`; trim `SKILLS=(…)`
   to the skills you want (and list any skills vendored from a *different* upstream in `EXTERNAL_SKILLS=(…)`
   so they're exempt from pruning).
2. **First sync needs no pin:** run `scripts/sync-agent-skills.sh`. It resolves the hub's default branch to a
   concrete 40-char SHA, verifies that SHA is an **ancestor** of the default branch (rejects a fork-only/off-
   branch pin), and records it in **`.agents/skills-lock.json`** — review the resolved SHA + `playbook_repo`
   in the diff. Re-run with no args to stay at the locked pin; `PLAYBOOK_REF=<new-sha>` to bump it.
3. The script vendors each whole skill directory into `.agents/skills/<name>/`, injects a provenance header
   into each `SKILL.md`, creates the `.claude/skills/` symlinks, **prunes** any skill dropped from `SKILLS`,
   writes the lockfile (pin + per-skill version), and (re)generates **`.agents/AGENT_RULES.md`** by deriving
   one routing line per vendored skill from its `description` first sentence (see
   [Agent rules](#agent-rules--the-generated-routing-index) below). **Integrity is a re-sync + git gate, not a hash:** `sync`
   is deterministic, so CI runs `scripts/sync-agent-skills.sh && git status --porcelain -- .agents .claude`
   (`git status --porcelain`, not `git diff --exit-code`, so an untracked orphaned skill dir is caught too) —
   any hand-edit, doctored lockfile, orphaned skill, or injected symlink reproduces drift and fails the build.
   Never hand-edit vendored files; they're clobbered on the next sync.
4. **Declare your gates** in a `project-gates` manifest at `.agents/gates.yaml` (categories, triggers,
   commands, flow — see the `project-gates` skill for the schema). This is the structured source of truth for
   your gates; see [`skills/project-gates/SKILL.md`](skills/project-gates/SKILL.md) for a filled example.
5. **Wire it into your `CLAUDE.md`**: replace the general guidance with thin skill-pointers that defer to the
   manifest, plus **one static import line** for the generated routing index (see below). Generic form:
   > *@.agents/AGENT_RULES.md*
   >
   > *Delegate per the `subagent-framework` skill; this project's gates are declared in `.agents/gates.yaml`
   > (`project-gates`). Log each delegation in `<log path>`. For review panels use the
   > `independent-expert-review` skill; persist rounds in `<research dir>`.*

   Concrete example (the Svelte/SvelteKit repo this was extracted from):
   > *@.agents/AGENT_RULES.md*
   >
   > *Delegate per the **`subagent-framework`** skill. **This project's gates** live in
   > `.agents/gates.yaml` (per **`project-gates`**) — always `bun run check` + `bun run lint`; logic
   > `bun run test:unit --run`; safety-specific `bun run test:stories` (axe) + `scripts/vrt.sh`. **Log every
   > delegation in `docs/subagent-log/`.** For neutral review panels use the **`independent-expert-review`**
   > skill; persist rounds dated in `docs/research/` and verify with the manifest's gates.*

### Agent rules — the generated rule index

Most skills are **load-on-demand**: the agent loads one when its `description` matches the situation. Some
rules need to be visible *before* the agent would think to look for a skill about them.

`sync-agent-skills.sh` therefore generates **`.agents/AGENT_RULES.md`** in two sections.

**`## Standing rules`** — self-contained instructions that hold on every turn, emitted verbatim from the
hub's [`standing-rules.md`](standing-rules.md) (only the bullets under its `## Rules` heading; everything
above it is maintainer documentation). **A standing rule may not name a skill**, and sync rejects one that
does: a line pointing at a skill is a *route*, and a route belongs in the section below, where the
generator owns its format so a compressed rule cannot drift from the skill it came from. A standing rule
has no source skill, so it has nothing to drift from — that is what makes it safe to state in full.
The section is capped at **800 bytes** total; it loads on every turn for every consumer, and the
predecessor mechanism (one hint field per skill) grew tenfold in two commits because each author saw only
their own line. One curated file has a single owner and a visible total.

**`## Which skill to load, and when`** — one line per vendored skill, pairing a trigger with the skill that
owns the rule.

```markdown
- **about to write real code, or spawning a subagent** → load `subagent-framework`
```

**The trigger is derived, not declared.** It is `description`'s **first sentence**, minus the `Use when`
lead-in — so there is no second field to drift out of sync with the first. Write the opener as a bare
trigger and put the detail after it:

```yaml
description: Use when filing a defect, or trusting a test or benchmark result. Also when checking a fix
  is actually guarded. The discipline that keeps evidence honest — reproduce a defect against the real …
```

The generator owns the whole line format; an author supplies only the trigger phrase. **A rule, threshold,
or caveat cannot be smuggled into always-loaded context**, so the index can never drift from or contradict
the skill it points at.

Import it once — `@.agents/AGENT_RULES.md` in `CLAUDE.md` — and it never needs touching again; new skills,
edits, and removals all arrive via the normal re-sync + pin bump. Line order follows your `SKILLS=(…)`
declaration order, so the index reads as a workflow.

> **Known limitation — the routes section is not justified by context budget.** Claude Code preloads every
> skill's `name` + `description` natively, so the routes duplicate what that harness already has: measured
> at 11 skills they add **+26%** to always-loaded context and save nothing
> (`scripts/measure-index-overhead.sh`). They are for harnesses *without* native preloading, where the
> index is the only channel. The **standing rules are unaffected** — no skill description carries them, so
> they have no alternative channel at any size. See
> [the decision record](docs/decisions/2026-09-14-routing-index-evidence.md) for the kill criteria.

Both `sync-agent-skills.sh` and `validate-skill.sh` cap the derived trigger at **120 characters**; an
over-long opener fails rather than silently bloating every consumer's context. (Harnesses without an import
mechanism need different wiring — not implemented here.)

`validate-skill.sh` additionally **warns on near-duplicate triggers** — at review time only, where the
maintainer who can reword a description sees it. (`sync` deliberately stays silent: a consumer cannot fix
hub-authored wording, so warning them every sync is noise they could only mute by dropping a skill.)

The measure is *lexical* — overlap of content words, stopwords dropped — so it catches a trigger written
by copying a neighbour's and tweaking it, and it will **not** catch two triggers that mean the same thing
in different words. That half stays a human judgment. It warns rather than fails: two genuinely paired
skills (the propose/review halves of one workflow) legitimately share vocabulary.

### Upgrading — re-copy the script when you bump the pin

`sync-agent-skills.sh` is vendored into your repo, so **a hub change to what gets generated is inert until
you re-copy the script.** That used to fail silently: a script from before the rules mechanism, run against
a hub that has it, deletes the rules file it knew about, writes no replacement, and exits 0 — with the
integrity gate clean, because the stale output is exactly what the stale script should produce.

The script now carries a `SYNC_SCRIPT_VERSION` and compares it against the hub's at the pinned SHA. Older
than the hub, it **refuses before touching the vendored tree** and names the fix; newer, it warns that the
pin is behind. It compares a version rather than a file hash on purpose — you are *expected* to edit
`SKILLS=(…)`, so a hash would differ on every legitimate run.

```
cp <hub>/scripts/sync-agent-skills.sh <hub>/scripts/lib.sh scripts/   # then restore your SKILLS list
```

`ALLOW_STALE_SYNC_SCRIPT=1` overrides it for a deliberate mid-migration run.

**This check cannot help a consumer whose script predates the check itself** — nothing we ship executes on
their machine until they re-copy it. That population is exactly what [`CHANGELOG.md`](CHANGELOG.md) is
for: it lives in the hub and is *read* at upgrade time rather than executed, so it reaches them regardless
of how old their scripts are. Every change needing work in the consuming repo carries a literal
**`ACTION REQUIRED`** marker, and `update-check.sh` prints the ones between your pin and upstream:

```
  ⚑ MIGRATION NOTES — hub changes since your pin that need action in THIS repo:
      ## 2026-09-14 — `88c0b58` (#17) Rule index replaces the per-skill hint field
        → ACTION REQUIRED: change your CLAUDE.md import line.
```

The two mechanisms cover complementary populations: the version check catches it mechanically but only
from v2 on; the changelog catches it for anyone, but only if they read it.

## Contributing a skill (propose → review)

This repo is the **hub**. To contribute a project-agnostic skill (or a fix), follow the **propose-skill**
skill: author `skills/<name>/SKILL.md` with the required frontmatter (`name`, `description`, semver
`version`, optional `requires`/`default-access`/`isolation`), run `scripts/build-registry.sh`, self-check
with `scripts/validate-skill.sh <name>`, and open a PR. A maintainer accepts it via the
**review-skill-proposal** skill (the `validate-skill.sh` mechanical checks + a judgment pass: genuinely
general, non-duplicative, safe, honestly versioned). On merge, the registry bump notifies downstream
consumers.

## Versioning, the registry & updates

Each skill carries a **`version`** (semver) in its frontmatter. **`registry.yaml`** (generated by
`scripts/build-registry.sh`) is the published index — per skill: `version`, content `sha256`, `requires`,
and `deprecated?`. Downstream consumers compare their `.agents/skills-lock.json` against `registry.yaml` to
find **updated** skills (locked version behind the registry), **new** skills (in the registry, not yet
vendored), and **deprecations** — that's the `update-check`. Hand-edits to vendored files are caught by the
**integrity gate**, not a separate hash: `sync` is deterministic, so CI's `sync && git status --porcelain`
reproduces any tampering (or an orphan, or an injected symlink) as drift. Bump a skill's `version` when you
change it, re-run `build-registry.sh`, and commit `registry.yaml`.

## Pinning

The **commit SHA is the canonical pin** — recorded in `.agents/skills-lock.json` and in each vendored copy's
header, since that's
what actually fixes the content. `VERSION` is a human-facing label that tracks releases; a matching git tag
(e.g. `v0.1.0`) may be cut alongside it for convenience, but always pin to the SHA.
