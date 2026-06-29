---
name: agent-access
description: Use when delegating to a sub-agent and deciding what it may touch and how isolated it runs, or when authoring a skill that should default to running in a fresh sub-agent. Defines the access-scope vocabulary (read-only / read+history / propose / write:<globs> / write, plus a network modifier) and the isolation model (inline vs sub-agent). Scopes resolve against the repo's .agents/access.yaml (agent-repo-layout); a delegation may never exceed a path's declared permission. subagent-framework's task-contract Constraints and independent-expert-review's read-only stance both use this vocabulary.
user-invocable: false
---

# Agent access & isolation — what a sub-agent may touch, and how isolated it runs

The standard vocabulary for **two orthogonal decisions** when delegating: *how isolated* a sub-agent runs,
and *what it's allowed to touch*. `subagent-framework`'s task contract (Constraints) and
`independent-expert-review` (read-only reviewers) both express their constraints in these terms; scopes
resolve against the repo's permission map (`agent-repo-layout` → `.agents/access.yaml`).

> **Parameterized:** the per-path ceiling lives in the host's `.agents/access.yaml`. This skill defines the
> scope/isolation *vocabulary*; the host defines *where* each permission applies.

## Isolation — inline vs sub-agent
- **inline** — the work runs in the main loop's own context (the default for guidance/decision skills).
- **subagent** — the work runs in a fresh sub-agent with its own context window (breadth/parallelism, or to
  keep a large read out of the main context).

A skill may declare a default in its frontmatter so the orchestrator knows how to run it:
```yaml
isolation: inline | subagent        # default inline
default-access: read-only | propose | read+history | write:<globs> | write   # default for sub-agents it spawns
```
**Honest scope:** these are **advisory orchestrator hints**, not a harness-enforced sandbox — the main loop
is expected to honour them (and the access ceiling below), the runtime doesn't force them. Treat a declared
scope as a contract the orchestrator upholds, and verify (don't trust) per `subagent-framework` §0.

## Access scopes (least-privilege; pick the smallest that fits)
| Scope | The sub-agent may… |
|---|---|
| `read-only` | read files, report findings — **no writes** (review panels, audits) |
| `read+history` | read-only **+** `git log`/`blame`/`show` for archaeology |
| `propose` | read-only, but emit a **diff/patch it does not apply** (the main loop applies after review) |
| `write:<globs>` | read, **and write only within the listed path globs** (e.g. `write:docs/**`, `write:.agents/scratch/**`) |
| `write` | read, and write within the delegation's stated file scope (general implementation) |
| modifier `network:on\|off` | whether the sub-agent may reach the network (default off for write tasks) |

**Default to the smallest scope that lets the task succeed.** A reviewer is `read-only`; a "suggest a fix"
task is `propose`; a docs/log update is `write:docs/**`; only a real implementation task is `write`.

## How scopes resolve against `.agents/access.yaml`
A scope is a **ceiling request**; the repo's permission map is the **hard ceiling**. The effective
permission is the *intersection*:
- A path marked **read-only** in `access.yaml` is never written, even under a `write` scope.
- A path marked **append** accepts new entries/files but not rewrites/deletes — a `write:` glob over it means
  *append*, not overwrite.
- A path marked **write** is freely writable. **scoped** paths (source) defer to the delegation's scope here.
- `write:<globs>` must name paths the map actually permits; naming a read-only path is an error, not an
  override.

## Mapping to real tooling
- `read-only` / `read+history` → a read-only search agent type; never grant write tools.
- `propose` → read-only tools + return a patch in the result; the main loop applies it.
- `write:<globs>` / `write` with **parallel** writers → isolate each in its own workspace (git worktree /
  clone) and join-verify (see `subagent-framework` §4); a single writer needs no worktree.
- Always **observe the gate yourself** after a write delegation — the scope limits blast radius, it does not
  certify correctness.
