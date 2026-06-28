# agent-playbook

Reusable, **project-agnostic** working method for coding agents (Claude Code and friends), packaged as
load-on-demand **skills**. Extracted so the method can be shared across repos while each consuming repo keeps
only its project-specific rules and concrete gate values.

## What's here

```
skills/
  subagent-framework/SKILL.md          # delegate to subagents & measure whether it worked:
                                        #   when to delegate, the task contract, size tiers,
                                        #   orchestration patterns, the eval scorecard, logging, guardrails
  agent-operating-principles/SKILL.md   # research-first · the troubleshooting playbook ·
                                        #   keep-the-troubleshooting-doc-current discipline
VERSION                                 # the human-facing release ref (consumers also pin a commit SHA)
```

Both skills are deliberately parameterized: they define the *slots* (which gates to run, where the logs and
docs live), and the **consuming repo supplies the values** — typically in its `CLAUDE.md`. Get that seam
right and a skill drops into a non-Svelte, non-JS repo unchanged.

> The canonical pin is the **commit SHA** recorded in each vendored copy (see [Versioning](#versioning));
> `VERSION` is a human-facing label.

## How to vendor it into a consuming repo

These skills are meant to be **vendored** (copied in + pinned), not submoduled — the proven pattern for
ephemeral fresh-clone web/sandbox containers, no submodule-init or egress-proxy friction.

1. Copy the skill folders into your repo's agent-skills directory, e.g.
   `.agents/skills/subagent-framework/` and `.agents/skills/agent-operating-principles/`.
2. Symlink them into the harness skills directory so they're discoverable, e.g.
   `.claude/skills/subagent-framework -> ../../.agents/skills/subagent-framework`.
3. **Pin the source ref** — record the `agent-playbook` commit SHA in each vendored copy (a header line) so
   you know exactly what you have and can re-sync deliberately.
4. In your `CLAUDE.md`, replace the general guidance with a thin pointer + your concrete gate values, e.g.
   *"Delegate per the `subagent-framework` skill. This project's gates: `<check>` · `<lint>` · `<unit>` ·
   `<a11y>` · `<vrt>`. Log each delegation in `<log path>`."*

A `sync-agent-skills.sh`-style script in the consuming repo can automate steps 1–3 against a pinned ref.

## Versioning

The **commit SHA is the canonical pin** — consumers record it in each vendored copy's header, since that's
what actually fixes the content. `VERSION` is a human-facing label that tracks releases; a matching git tag
(e.g. `v0.1.0`) may be cut alongside it for convenience, but always pin to the SHA.
