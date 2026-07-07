# Independent-expert-review — "default to Bun for JS/web-dev tooling"

**Date:** 2026-07-07
**Artifact under review:** commit adding a "Default web-dev toolchain — reach for Bun" paragraph to
`skills/agent-operating-principles/SKILL.md` §1 (+ frontmatter `description` edit, `version` 1.0.0 → 1.1.0,
regenerated `registry.yaml`).
**Panel:** 3 neutral read-only reviewers, identical scope, run in parallel — lenses: **playbook coherence**,
**factual accuracy**, **skill-authoring clarity**.

## Panel verdicts
- **Coherence:** *not-sound* — a hard Bun default inverts the repo's project-agnostic "host supplies the
  values" seam; mis-homed in a research-before-build section; rests on an overstated standardization claim.
- **Accuracy:** *accurate-with-corrections* — Bun subcommands, the `project-gates`/devcontainer sub-claims,
  the semver bump, and the registry regeneration are all correct; the lone defect is "the vendoring docs all
  assume it" (the vendoring machinery is Bun-free).
- **Clarity:** *clear-with-edits* — core directive is clear, but "runtime"/"bundler" contradict the cited
  devcontainer (Node base image + Vite), and the "exception to re-researching" hook is a category stretch.

## Findings verified against the code (main-loop synthesis)
| Sev | Finding | Verification | Disposition |
|-----|---------|--------------|-------------|
| MAJOR (×2) | "the vendoring docs all assume it" is false | `grep bun scripts/` empty; `lib.sh:4` deps = bash/coreutils/jq; `sync-agent-skills.sh:24` `require_tools git jq` | **Accepted** — claim removed; cite only project-gates examples + devcontainer |
| MAJOR | "runtime"/"bundler" contradict the cited devcontainer | `agent-repo-layout/SKILL.md:98` Node base image, `:122` Vite dev-server, `:86` Bun listed neutrally beside `CARGO_HOME`/`PNPM_HOME` | **Accepted** — scoped to package manager / script runner / test runner; dropped node/npx-runtime |
| BLOCKER | seam inversion — Bun default demotes the host's own toolchain to "the exception" | `README.md:50-52` (parameterized, examples-not-standards), `SKILL.md:17` (resolve slots from host) | **Accepted via reconciliation** — "match the host first" is now primary; Bun is the *greenfield* default (preserves the requested Bun preference without overriding a host's existing lockfile) |
| MAJOR | residual bias: a quiet npm/pnpm repo (no loud "standard") would get Bun forced | reasoning from the seam contract | **Accepted** — folded into "match the host first / a second lockfile is its own bug" |
| MAJOR/MINOR | wrong home + "exception to re-researching" is a category error (§1 is about researching libraries to build, not toolchain selection) | `SKILL.md:23` heading, `:25` "component, feature, or capability" | **Partially accepted** — reframed as "distinct from the research habit … which tool to invoke, not what to build"; the deeper *relocation* question (own section vs `agent-repo-layout`) left open for the maintainer |
| MINOR | overstated "playbook's standardized toolchain" | `project-gates/SKILL.md:65` commands live under "## Example (a Svelte/SvelteKit repo)" | **Accepted** — downgraded to "the toolchain the playbook's own examples use" |
| MINOR | "note why at the call site" is fuzzy for a toolchain choice (no single code call site) | — | **Accepted** — locus is now the gate manifest / lockfile |
| MINOR/NIT | description coupling; description lopsided | `SKILL.md:3` | **Partially accepted** — kept a tightened mention (the guidance genuinely lives in §1 now) |
| NIT | `[Bun](https://bun.sh)` is the only inline external link across sibling skills | — | **Kept** — a single canonical link to the tool is reasonable |

## What was done right (per panel)
- Blast radius scoped to "when what you need is a JS/TS tool" — non-JS repos untouched.
- Escape hatch + "note why" hygiene present from the start.
- Mechanically clean: correct additive minor bump; `registry.yaml` regenerates reproducibly
  (`build-registry.sh` then `git status --porcelain` clean); `validate-skill.sh` passes.

## Open question for the maintainer (not auto-resolved)
Two reviewers argued a *toolchain* default doesn't belong inside §1 ("Research existing OSS before building").
Options: (a) keep it as a delineated standalone default within §1 (current state); (b) promote it to its own
top-level principle (changes the skill's "four habits" framing); (c) relocate it to `agent-repo-layout`, which
already owns devcontainer/toolchain conventions. Left for a human call.
