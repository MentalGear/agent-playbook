# Vendoring mechanism — expert-review round, 2026-07-01

Independent-expert-review panel over the **merged** skill-vendoring / update mechanism (post-pivot +
the four update-correctness checks): hub `agent-playbook` (`lib.sh`, `sync-agent-skills.sh`,
`update-check.sh`, `build-registry.sh`, `validate-skill.sh`, `registry.yaml`, `ci.yml`) and consumer
`SupraAppKit` (mirrored `scripts/*`, `.agents/skills-lock.json`, `agent-skills.yml`,
`skills-update-check.yml`, `.githooks/pre-push`, `CLAUDE.md`, `.agents/access.yaml`).

**Panel:** 4 neutral reviewers, identical scope, each blind to any desired conclusion — supply-chain
security · shell robustness · CI/reproducibility · dependency-management DX. Findings below are only
those **re-verified against the code in the main loop**; rejected panel claims are listed at the end.

## Bottom line
The mechanism is sound. Shell review found ~nothing (one NIT); no reviewer found a way for CI to go
green on tampered *synced* content. The real issues were **doc-vs-implementation drift** and two
**defense-in-depth** gaps — not correctness bugs.

## Verified findings + disposition

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| ① | MAJOR | Canonical docs/comments prescribe `git diff --exit-code` for the vendoring gate, but `git diff` ignores untracked files, so an **orphaned skill dir (case C)** slips past it. The deployed consumer CI already uses `git status --porcelain`. Flagged by 3/4 reviewers. | **Fixed** — README, pivot ADR, `lib.sh`, `sync-agent-skills.sh` (both repos) → `git status --porcelain`. `registry.yaml`-freshness references (a *tracked* file) correctly keep `git diff`. |
| ② | MAJOR | The gate scripts (`sync-agent-skills.sh`, `lib.sh`) *are* the integrity TCB, yet sat under `**` → `scoped` in `access.yaml`, not `approval` like the other contract files. PR review is the real boundary (per the ADR); this is defense-in-depth/consistency. | **Fixed (approved)** — both scripts added to the `approval` tier in `.agents/access.yaml`. |
| ③ | MINOR | `EXTERNAL_SKILLS` (`shadcn-svelte`, `svelte-core-bestpractices`) are out-of-perimeter but invisible in `CLAUDE.md`. | **Fixed (approved)** — documented in the "Repo layout & access" paragraph. |
| ④ | MINOR | Adopting a NEW skill silently needs a manual `SKILLS=()` edit; re-sync without it leaves the skill unvendored and the gate sees no change. | **Fixed** — `update-check.sh` (both repos) now warns loudly; `CLAUDE.md` states the two-step. |
| ⑤ | MINOR | `skills-update-check.yml` ended the check with `\|\| true`, so a misconfig (bad lockfile / missing jq) masqueraded as "up to date" and silently disabled the monitor. | **Fixed** — capture the exit code; fail the job on a genuine error, still treat "behind" as non-error. |

## Rejected on verification (not carried)
- *"Re-sync hides committed poison"* — re-sync **overwrites/scrubs** a poisoned skill with the clean
  upstream copy; the poison doesn't survive. Not a vuln.
- *"`playbook_repo` vs `AGENT_PLAYBOOK_REPO` manual coordination"* — CI asserts equality
  (`agent-skills.yml`) and **fails closed** on mismatch.
- *"Hub may not validate incoming skills at PR time"* — hub `ci.yml` runs `validate-skill.sh --all`
  + registry-freshness + tests on `pull_request`.
- US-separator / `sort -V` fragility — no defect; currently correct and covered by tests.

## Note (raised, not actioned)
`skill_dir_hash` remains in the consumer's `lib.sh` but is **never called** there (hub-only: it
computes `registry.yaml`'s `sha256`). Kept intentionally — `lib.sh` is copied verbatim from the hub
(the hub's `hash-consistency.test.sh` enforces single-source), so the consumer carries the whole
shared lib and uses part of it. Splitting shared-readers vs hub-only-hash is a larger design choice,
deferred.

## Verification performed
shellcheck + `bash -n` clean (both repos); hub tests 4/4 green; `registry.yaml` unchanged; consumer
re-sync against the pinned tree (`b3ad44a`, via worktree) = **no drift**; both workflows parse;
`update-check` runs (exit 0, ④ warning renders). Landed on `claude/agent-playbook-extraction-w0escf`.
