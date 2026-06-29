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
VERSION                                 # the human-facing release ref (consumers also pin a commit SHA)
```

The skills interlock: **subagent-framework** is the delegation contract, **independent-expert-review** is the
review-panel pattern it references, and **agent-operating-principles** is the cross-cutting working
discipline. A skill folder may carry extra files beyond `SKILL.md` (e.g. `subagent-framework/reference.md`),
so vendor the **whole skill directory**, not just the entry file.

All three are deliberately parameterized: they define the *slots* (which gates to run, where the logs and
docs live), and the **consuming repo supplies the values** — typically in its `CLAUDE.md`. Get that seam
right and a skill drops into a non-Svelte, non-JS repo with only its slot values changed (`subagent-framework`'s
§3a gate categories are an open list — UI a11y/visual-regression are *examples* of the safety-specific
category, not required gates).

> The canonical pin is the **commit SHA** recorded in each vendored copy (see [Versioning](#versioning));
> `VERSION` is a human-facing label.

## How to vendor it into a consuming repo

These skills are meant to be **vendored** (copied in + pinned), not submoduled — the proven pattern for
ephemeral fresh-clone web/sandbox containers, no submodule-init or egress-proxy friction.

**Use the provided sync script — don't hand-copy.** [`scripts/sync-agent-skills.sh`](scripts/sync-agent-skills.sh)
is the canonical vendoring tool; copying files by hand drifts and loses the pin. Steps:

1. **Copy the script** into your repo at `scripts/sync-agent-skills.sh`.
2. **Pin it**: set `PLAYBOOK_REF` to the `agent-playbook` commit SHA you want (the SHA is the real pin), and
   trim `SKILLS=(…)` to the skills you want.
3. **Run it.** It vendors each whole skill directory into `.agents/skills/<name>/` (incl. files like
   `reference.md`), injects a provenance SHA header into each `SKILL.md`, and creates the `.claude/skills/`
   symlinks the harness discovers. Re-run it to update the pin — never hand-edit vendored files (they carry
   a "do not edit here" header and are clobbered on the next sync).
4. **Wire it into your `CLAUDE.md`**: replace the general guidance with a thin pointer + your concrete gate
   values (fill the slots each skill defines). Generic form:
   > *Delegate per the `subagent-framework` skill. This project's gates: `<check>` · `<lint>` · `<unit>` ·
   > `<safety-specific>`. Log each delegation in `<log path>`. For review panels use the
   > `independent-expert-review` skill; persist rounds in `<research dir>`.*

   Concrete example (a Svelte/SvelteKit repo — the project this was extracted from):
   > *Delegate per the **`subagent-framework`** skill. **This project's gates** (its §3a categories, filled
   > in): always = `bun run check` + `bun run lint`; logic = `bun run test:unit --run`; safety-specific =
   > `bun run test:stories` (axe a11y) for UI + `scripts/vrt.sh` (visual regression). **Log every delegation
   > in `docs/subagent-log.md`.** For neutral review panels use the **`independent-expert-review`** skill;
   > persist rounds dated in `docs/research/` and verify findings with the gates above.*

## Versioning

The **commit SHA is the canonical pin** — consumers record it in each vendored copy's header, since that's
what actually fixes the content. `VERSION` is a human-facing label that tracks releases; a matching git tag
(e.g. `v0.1.0`) may be cut alongside it for convenience, but always pin to the SHA.
