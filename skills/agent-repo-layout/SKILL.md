---
name: agent-repo-layout
description: Use when setting up a repo for agents, or when unsure where an agent-facing artifact belongs or whether you may write to a path. Defines the standard agent-facing repo layout (.agents/ for skills, gates, access map, scratch; docs/ folders for research, troubleshooting, the delegation log) and a path→permission map (.agents/access.yaml) that the agent-access scopes resolve against, and the convention that an agent-ready repo ships a working devcontainer (boots clone-to-ready). The host fills access.yaml with its real paths; this skill defines the convention.
user-invocable: false
version: 1.1.0
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
  - glob: "CLAUDE.md"           # the operating contract — propose a diff + get approval, never silent
    permission: approval
  - glob: ".agents/skills/**"   # vendored — managed only by the sync script
    permission: read-only
  - glob: ".agents/gates.yaml"  # part of the contract
    permission: approval
  - glob: ".agents/access.yaml" # changes the permission model itself
    permission: approval
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
- **approval** — may be changed only by **showing the proposed diff and getting explicit human approval
  first** (never silently). For the **operating contract** — `CLAUDE.md`, `.agents/access.yaml`,
  `.agents/gates.yaml` — where a change alters how every future agent behaves. (Same spirit as
  `review-skill-proposal`: a model validates and proposes, a human accepts.)

## How an agent uses this
1. **Placing an artifact?** Put it in the role's standard folder (a debugging finding → `docs/debug/`; a
   research capture → `docs/research/`; a delegation entry → `docs/subagent-log/`; throwaway → scratch).
2. **About to write a path?** Check `.agents/access.yaml`: `read-only` → don't; `append` → add, don't rewrite;
   `write` → free; `scoped` → only within the delegation's `agent-access` scope; `approval` → show the diff
   and get a human yes first (the contract files).
3. **Never hand-edit `.agents/skills/**`** — it's sync-managed and carries a "do not edit here" header.

## Ship a working devcontainer
**An agent-ready repo boots clone-to-ready.** Ship a `devcontainer.json` so a fresh clone reaches a
runnable state — toolchain installed, tool binaries on `PATH`, dependencies installed, and (if the project
verifies in a browser) the browser present — **with no manual steps**. Agents in cloud/web environments
depend on this; "works on my machine" silently breaks them. The acceptance bar: a **cold rebuild** (no
cache) reaches green run/test/build + a started dev server, and any best-effort step (a heavy download)
fails soft without failing creation. A devcontainer that's never been cold-built doesn't work yet.

Gotchas that have cost real time:
- **Install dir must be user-writable** — point the installer at the container user's home via its env var
  (`BUN_INSTALL`, `CARGO_HOME`, `PNPM_HOME`, …).
- **`PATH` goes in `remoteEnv`, not `containerEnv`** — only there does `${containerEnv:PATH}` resolve against
  the real PATH; a `containerEnv` PATH is passed literally to `docker run` and clobbers it.
- **Inline the installer's env var** at the command so it can't read a stale `containerEnv` value at create.
- **Use full tool paths in `postCreateCommand`** — `remoteEnv`'s PATH may not be active yet during create.
- **Make heavy/optional installs best-effort** (`… || echo skipped`) so a flaky download can't fail create.

A known-good reference (Bun + browser verification), **verified on GitHub Codespaces**, resolving all of
the above:
```jsonc
{
  "name": "Devcontainer (works with github codespaces)",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:22-bookworm",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {}
  },
  // BUN_INSTALL tells the bun installer where to put bun (must be user-writable).
  // /home/node/.bun is the default location for the non-root "node" user in this image.
  // PATH is in remoteEnv (not containerEnv) so ${containerEnv:PATH} resolves correctly
  // against the container's real PATH instead of being passed literally to docker run.
  "containerEnv": {
    "BUN_INSTALL": "/home/node/.bun",
    "PLAYWRIGHT_BROWSERS_PATH": "/opt/pw-browsers"
  },
  "remoteEnv": {
    "PATH": "/home/node/.bun/bin:${containerEnv:PATH}"
  },
  // Install Bun once when the container is created.
  // Explicit BUN_INSTALL=... inline so the installer never picks up a stale containerEnv value.
  "onCreateCommand": "curl -fsSL https://bun.sh/install | BUN_INSTALL=/home/node/.bun bash",
  // Install JS deps and (best-effort) the Chromium used for browser verification.
  // Use the full path so this works before remoteEnv PATH is active.
  "postCreateCommand": "/home/node/.bun/bin/bun install && (/home/node/.bun/bin/bunx playwright install --with-deps chromium || echo 'playwright chromium install skipped')",
  "forwardPorts": [5173],
  "portsAttributes": {
    "5173": {
      "label": "Vite dev server",
      "onAutoForward": "openBrowser"
    }
  },
  "customizations": {
    "vscode": {
      "extensions": ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode"]
    }
  }
}
```
