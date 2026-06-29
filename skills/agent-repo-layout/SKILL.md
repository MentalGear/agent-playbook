---
name: agent-repo-layout
description: Use when setting up a repo for agents, or when unsure where an agent-facing artifact belongs or whether you may write to a path. Defines the standard agent-facing repo layout (.agents/ for skills, gates, access map, scratch; docs/ folders for research, troubleshooting, the delegation log) and a path→permission map (.agents/access.yaml) that the agent-access scopes resolve against. The host fills access.yaml with its real paths; this skill defines the convention.
user-invocable: false
version: 1.0.0
---

# Agent repo layout — where things live, and what may write where

A standard, predictable home for agent-facing artifacts, plus an explicit **permission map** so an agent
knows — without guessing — which paths are read-only, append-only, or writable. The host fills the paths;
this skill defines the convention. Pairs with **agent-access** (the scope vocabulary that resolves against
this map), **project-gates** (the gate manifest), and the **subagent-framework** (which reads the log).

> **Parameterized skill — the host supplies `.agents/access.yaml`** (the path→permission map) and may relocate
> any path below. This skill defines the *roles*; the host names the *paths*.

## Standard layout
```
.agents/
  skills/        # vendored skills            — READ-ONLY (sync-managed; "do not edit here")
  gates.yaml     # the project-gates manifest — READ-ONLY config
  access.yaml    # the path→permission map    — READ-ONLY config (this skill's slot)
  scratch/       # agent scratch space        — WRITE, gitignored (throwaway)
docs/
  research/      # prior-art / design / review-round captures — APPEND (one file per topic/round, dated)
  debug/         # the troubleshooting reference — APPEND (a folder so it can hold one file per topic)
  subagent-log/  # the delegation log            — APPEND (a folder so it can hold per-period/topic files)
```
**Why folders for `debug/` and `subagent-log/`:** they grow without bound and span topics; a folder lets
each topic/period be its own file with a `README.md` index, instead of one ever-growing file. Single-file
repos can start with just `<folder>/README.md` and split later.

## The permission map (`.agents/access.yaml`)
Declares what may write where. The **agent-access** scopes (`write:<globs>`, `propose`, `read-only`, …)
resolve against it; a delegation may never exceed the path's declared permission.
```yaml
# .agents/access.yaml — path → permission for agents/sub-agents
paths:
  - glob: ".agents/skills/**"   # vendored — managed only by the sync script
    permission: read-only
  - glob: ".agents/gates.yaml"
    permission: read-only
  - glob: ".agents/access.yaml"
    permission: read-only
  - glob: ".agents/scratch/**"
    permission: write
  - glob: "docs/research/**"
    permission: append            # add files; don't rewrite history
  - glob: "docs/debug/**"
    permission: append
  - glob: "docs/subagent-log/**"
    permission: append
  - glob: "**"                    # everything else (source): governed by the delegation's access scope
    permission: scoped            # see the agent-access skill — the task contract sets the scope
```
- **read-only** — never written by an agent (config, vendored content).
- **append** — add entries/files; don't rewrite or delete existing history (logs, research, troubleshooting).
- **write** — free to create/modify/delete (scratch).
- **scoped** — defer to the delegation's declared access scope (`agent-access`); source code lives here.

## How an agent uses this
1. **Placing an artifact?** Put it in the role's standard folder (a debugging finding → `docs/debug/`; a
   research capture → `docs/research/`; a delegation entry → `docs/subagent-log/`; throwaway → scratch).
2. **About to write a path?** Check `.agents/access.yaml`: `read-only` → don't; `append` → add, don't rewrite;
   `write` → free; `scoped` → only within the delegation's `agent-access` scope.
3. **Never hand-edit `.agents/skills/**`** — it's sync-managed and carries a "do not edit here" header.
