# Vendoring mechanism — expert-review round 4, 2026-07-01

Panel over the **final** state (after the round-3 ancestry-gating revert + the new regression test). Lenses:
supply-chain security · test engineering/QA · correctness & consistency. Identical scope, each reviewer
blind to the change history and the desired conclusion. Findings below are only those **re-verified in the
main loop**.

## Headline
No real vulnerability. The **consistency reviewer found nothing**; the two "BLOCKER"s (security + QA) are the
**same** finding — the `AGENT_PLAYBOOK_SRC` local path skips the ancestry check — and both downgrade on
verification: **no CI or hook uses `AGENT_PLAYBOOK_SRC`** (grep-confirmed), so it is not a CI bypass. The
consumer gate uses the clone path, where ancestry runs unconditionally and `sync.test.sh` case 16 proves a
hand-edited off-branch pin is rejected. Real yield: test-coverage gaps + one comment that overclaims.

## Verified findings + disposition

| # | Panel sev → verified | Finding | Disposition |
|---|-----|---------|-------------|
| A | BLOCKER → **MINOR** | `AGENT_PLAYBOOK_SRC` (local/dev/test) path skips ancestry (`sync-agent-skills.sh` SRC branch vs the clone-path check). | **Not a CI bypass** — no workflow/hook sets `AGENT_PLAYBOOK_SRC`; CI uses `AGENT_PLAYBOOK_REPO` (clone path → ancestry), and any off-branch pin committed via local vendoring is caught by the CI re-sync at PR time. It's a deliberately-trusted local path. **Fix = clarify the comment** (below); adding ancestry to the SRC path would break the test harness + offline dev (local hubs have no `origin/HEAD`). |
| B | (A's) MINOR | The reverted comment says ancestry "Runs UNCONDITIONALLY", which a careful reviewer read as "in all paths" — but the SRC path skips it. The wording misleads. | **Propose (approval — edits `sync-agent-skills.sh`):** clarify that ancestry binds in the clone path (CI); the SRC path trusts the local checkout by design. |
| C | MAJOR → **MINOR/deferred** | Rollback guard fails **open** (WARN + proceed) when the old locked pin is absent from fetched history. | Not exploitable for an off-branch bump: **ancestry runs before the rollback guard** (`:90` before `:112`), so an off-default-branch bump is already rejected. The guard only covers a same-branch backward move; fail-open is intentional for legit hub squashes/rewrites. Already-deferred option to make it fail-closed. |
| D | MAJOR → **MINOR (coverage)** | `update-check.sh` offline/no-registry `exit 0` paths are untested. | **Apply:** add `update-check.test.sh` cases (offline skip, no registry → exit 0 + message). Behavior is intentional (advisory); the round-2 `::warning::` gives CI visibility. |
| E | MINOR (coverage) | No test documents the SRC-path ancestry asymmetry or the rollback fail-open branch. | **Apply:** add `sync.test.sh` cases pinning both behaviors so they can't silently change. |
| F | NIT | `sync.test.sh:86` (case 9) mutates the shared `$hub` (creates a `side` branch). | **Apply:** give case 9 its own hub. |

## Rejected framing / not carried
- The "BLOCKER" severity on A — rejected as a CI bypass (no CI path uses `AGENT_PLAYBOOK_SRC`); kept as a
  MINOR comment/doc fix.
- "Make the SRC path run ancestry" — rejected: it would break the test harness and offline dev (local hubs
  have no resolvable `origin/HEAD`); the gate correctly binds at CI's clone path.

## Passed clean
Consistency reviewer: no findings — hub↔consumer scripts identical except the legitimate `SKILLS` /
`EXTERNAL_SKILLS` config lines; lockfile shape matches the `lib.sh` readers; docs match the `git status`
gate; `access.yaml`/`CLAUDE.md` accurate. QA reviewer confirmed determinism, tamper-restore, git-status-vs-
diff, and case 16 are solid.

## Verification performed
Grep confirmed no `AGENT_PLAYBOOK_SRC` in any workflow/hook; confirmed ancestry (`:90`) precedes the rollback
guard (`:112`); hub↔consumer script diff = only the config arrays. Proposed/accepted fixes are test-only
(non-contract) except the comment clarification (approval-tier).
