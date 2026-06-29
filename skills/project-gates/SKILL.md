---
name: project-gates
description: Use when setting up a repo's quality gates, or deciding which gates to run before a change lands. Defines the structured gates manifest a host repo declares (e.g. .agents/gates.yaml) — gate categories (always / logic / safety-specific), each gate's trigger + command, and the ordered flow of actions between them (inspect-diff → gates → commit). This is the single source for the gate schema that the subagent-framework skill (which gates run before work lands) and independent-expert-review skill (verification gates) both reference. The host writes the manifest; this skill defines its shape.
user-invocable: false
---

# Project gates — the structured gate manifest

A host repo's quality gates are **declared once, in a structured manifest** (default `.agents/gates.yaml`),
not scattered as prose. This skill defines the manifest's shape; the host fills it with concrete commands.
Other skills reference it: **subagent-framework** runs the matching gates before a delegation lands;
**independent-expert-review** uses them as the verification gates; **agent-operating-principles** §4 (TDD)
writes to the `logic` gate.

> **Parameterized skill — the host supplies the manifest.** Write `.agents/gates.yaml` (path is the host's
> choice; point `CLAUDE.md` at it). This skill is the schema + how to read it; the values are the project's.

## The schema
```yaml
gates:                      # the list of gates this repo has
  - id: <short-name>
    category: always | logic | safety-specific
    when: <human-readable trigger>          # when this gate applies
    when_paths: ["glob", ...]               # optional: machine-evaluable trigger (changed-file globs)
    preflight: <shell>                      # optional: setup that must run first (e.g. start a daemon)
    run: <shell command>                    # the gate itself; non-zero exit = fail

flow:                       # the ordered actions a change goes through (gates *and* the steps between)
  - <action or run-gates step>

locations:                  # other slots the skills consume
  delegation_log: <path>    # subagent-framework's two-tier log
  review_rounds: <dir>      # where independent-expert-review persists rounds
```

### Categories (an open list — run what the change's risk surface demands)
- **always** — runs on every change (typically a type/compile check + lint).
- **logic** — runs when the change touches behaviour (unit / integration tests).
- **safety-specific** — the gates a particular risk surface needs. For UI: an accessibility check + a
  visual-regression run. For concurrency/services: a race detector, fuzz, or contract tests. A repo with no
  such surface simply declares none — don't invent gates you don't have.

## How to read & run it
1. **Always-gates run every time.** No exceptions.
2. **Run a `logic`/`safety-specific` gate when its trigger matches the change** — judge by `when` (or, if
   present, `when_paths` against the changed files). Don't run all gates by reflex; don't skip a matching one.
3. **Honour `preflight`** before its gate.
4. **Gate truth is the command's exit status / output — never an agent's prose claim** that it passed.
5. Follow `flow` for the order of actions (e.g. inspect the diff → run matching gates → commit).

> **Future (backlogged): an executable runner.** `when_paths` is included so a thin runner could, given a
> changed-file set, run exactly the matching gates (and back a pre-commit/-push hook). Until then the
> manifest is read and run by the agent. Adopting the manifest now keeps that path open without committing
> to the runner.

## Example (a Svelte/SvelteKit repo)
```yaml
gates:
  - id: check
    category: always
    when: every change
    run: bun run check            # svelte-check, expect 0
  - id: lint
    category: always
    when: every change
    run: bun run lint
  - id: unit
    category: logic
    when: change touches behaviour/logic
    run: bun run test:unit --run
  - id: a11y
    category: safety-specific
    when: a UI component or story is added/edited
    when_paths: ["**/*.svelte", "**/*.stories.*"]
    run: bun run test:stories     # axe
  - id: vrt
    category: safety-specific
    when: a styled/visual source file changes
    when_paths: ["**/*.svelte", "**/*.css", "packages/ui/**", "src/**"]
    preflight: docker info >/dev/null 2>&1 || (nohup dockerd >/tmp/dockerd.log 2>&1 &)  # debug-troubleshooting §10
    run: scripts/vrt.sh

flow:
  - inspect-diff                  # bound the expected size; read it
  - run-gates: [always]
  - run-gates: [matched]          # logic/safety gates whose trigger hits the diff
  - commit
  - push

locations:
  delegation_log: docs/subagent-log.md
  review_rounds: docs/research/
```
