# agent-playbook

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
  agent-operating-principles/SKILL.md   # research-first · the troubleshooting playbook ·
                                        #   keep-the-troubleshooting-doc-current discipline
  independent-expert-review/SKILL.md    # neutral multi-discipline review panels: sizing, the reviewer
                                        #   contract, finding schema, synthesis + per-finding verification
  project-gates/SKILL.md                # the gate-manifest schema (categories, triggers, flow) that
                                        #   subagent-framework + independent-expert-review reference
  agent-repo-layout/SKILL.md            # standard .agents/ + docs/ layout and the path→permission map
                                        #   (.agents/access.yaml) that agent-access scopes resolve against
  agent-access/SKILL.md                 # access-scope vocabulary (read-only/propose/write:<globs>/write) +
                                        #   isolation (inline vs sub-agent); resolves against access.yaml
registry.yaml                           # published index (per-skill version, sha256, requires, deprecated)
scripts/
  sync-agent-skills.sh                  # canonical vendoring tool (copy into your repo; writes the lockfile)
  build-registry.sh                     # regenerate registry.yaml from skill frontmatter
  drift-check.sh                        # consumer: vendored skills vs lockfile (hand-edit guard; pre-push)
  update-check.sh                       # consumer: lockfile vs upstream registry (new/updated/deprecated)
VERSION                                 # the human-facing release ref (consumers also pin a commit SHA)
```

The skills interlock: **subagent-framework** is the delegation contract, **independent-expert-review** is the
review-panel pattern it references, **project-gates** is the shared gate-manifest schema both of them point
at, **agent-repo-layout** is the standard repo structure + permission map, **agent-access** is the
scope/isolation vocabulary delegations declare (resolving against that map), and **agent-operating-principles**
is the cross-cutting working discipline. A skill folder may carry
extra files beyond `SKILL.md` (e.g. `subagent-framework/reference.md`), so vendor the **whole skill
directory**, not just the entry file.

All four are deliberately parameterized: they define the *slots* (which gates to run, where the logs and
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

1. **Copy the script** into your repo at `scripts/sync-agent-skills.sh`; trim `SKILLS=(…)` to the skills you
   want.
2. **First sync with a pin:** `PLAYBOOK_REF=<sha> scripts/sync-agent-skills.sh`. Thereafter the pin lives in
   **`.agents/skills-lock.json`** (not baked into the script) — re-run with no args to stay at the locked
   pin, or `PLAYBOOK_REF=<new-sha>` to bump it deliberately.
3. The script vendors each whole skill directory into `.agents/skills/<name>/` (incl. files like
   `reference.md`), injects a provenance header into each `SKILL.md`, creates the `.claude/skills/` symlinks
   the harness discovers, and writes the lockfile (pin + per-skill version + content hashes). Never hand-edit
   vendored files — they carry a "do not edit here" header, the lockfile records their hash (so the
   drift-check catches edits), and they're clobbered on the next sync.
4. **Declare your gates** in a `project-gates` manifest at `.agents/gates.yaml` (categories, triggers,
   commands, flow — see the `project-gates` skill for the schema). This is the structured source of truth for
   your gates; see [`skills/project-gates/SKILL.md`](skills/project-gates/SKILL.md) for a filled example.
5. **Wire it into your `CLAUDE.md`**: replace the general guidance with thin skill-pointers that defer to the
   manifest. Generic form:
   > *Delegate per the `subagent-framework` skill; this project's gates are declared in `.agents/gates.yaml`
   > (`project-gates`). Log each delegation in `<log path>`. For review panels use the
   > `independent-expert-review` skill; persist rounds in `<research dir>`.*

   Concrete example (the Svelte/SvelteKit repo this was extracted from):
   > *Delegate per the **`subagent-framework`** skill. **This project's gates** live in
   > `.agents/gates.yaml` (per **`project-gates`**) — always `bun run check` + `bun run lint`; logic
   > `bun run test:unit --run`; safety-specific `bun run test:stories` (axe) + `scripts/vrt.sh`. **Log every
   > delegation in `docs/subagent-log/`.** For neutral review panels use the **`independent-expert-review`**
   > skill; persist rounds dated in `docs/research/` and verify with the manifest's gates.*

## Versioning, the registry & updates

Each skill carries a **`version`** (semver) in its frontmatter. **`registry.yaml`** (generated by
`scripts/build-registry.sh`) is the published index — per skill: `version`, content `sha256`, `requires`,
and `deprecated?`. Downstream consumers compare their `.agents/skills-lock.json` against `registry.yaml` to
find **updated** skills (locked version behind the registry), **new** skills (in the registry, not yet
vendored), and **deprecations** — that's the `update-check`. A separate `drift-check` recomputes the
vendored files' hashes against the lockfile to catch hand-edits. Bump a skill's `version` when you change it,
re-run `build-registry.sh`, and commit `registry.yaml`.

## Pinning

The **commit SHA is the canonical pin** — recorded in `.agents/skills-lock.json` and in each vendored copy's
header, since that's
what actually fixes the content. `VERSION` is a human-facing label that tracks releases; a matching git tag
(e.g. `v0.1.0`) may be cut alongside it for convenience, but always pin to the SHA.
