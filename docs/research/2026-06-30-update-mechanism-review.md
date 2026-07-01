# Update-mechanism review — 2026-06-30

Independent-expert-review round on the skill-vendoring / update mechanism (consumer side: SupraAppKit
`scripts/sync-agent-skills.sh`, `drift-check.sh`, `update-check.sh`, `.agents/skills-lock.json`; hub side:
agent-playbook `build-registry.sh`, `validate-skill.sh`, `registry.yaml`, CI). Prompted by two questions:
**(1) can the first-time pin be automated without weakening security?** and **(2) how to make the update
mechanism easier while keeping it secure?**

Panel: 4 neutral reviewers — supply-chain security · shell robustness · dependency-management DX ·
CI/reproducibility. Each blind to any desired conclusion. Findings below are **only those verified against
the code in the main loop** (panel claims that didn't survive verification are noted).

## Headline answer — first-pin automation: YES, safely

The mechanism already resolves any ref to a concrete `resolved_sha` (`sync-agent-skills.sh:55`) and writes
that to the lockfile (`:106`). So automating the first pin is a *small* change, not a new trust model:
stop hard-erroring when no pin is given (`:30-33`), default `PLAYBOOK_REF` to `main`, resolve, pin the
resolved SHA, and print it loudly. The safety invariant — **never store a moving ref; the resolved
immutable SHA lands in the committed lockfile = a reviewable diff** — is preserved because that is already
how the resolve-and-write path works. This is the npm/Cargo/`go get` "lockfile on first install" model.

## Verified findings (severity assigned in the main loop, post-verification)

### MAJOR

1. **The pin is never verified against upstream; `sha256_source` is dead data.**
   `sha256_source` is written (`sync:98`) but read by *nothing* (grep across scripts/hooks/CI confirms only
   `sync` writes it; `pinned_sha` is read at `sync:28` as the re-sync pin, but only that). `drift-check`
   only proves *vendored == lockfile* (`drift-check.sh:24`, keys on `sha256_vendored`) — never *vendored ==
   agent-playbook@pinned_sha*. Honest threat model: this is **not** defense against a repo committer (they
   can edit the lockfile *and* the checker). Its value is (a) catching accidental divergence (botched
   vendor / bad merge), (b) making the pin *authentic* — re-fetch the hub at `pinned_sha`, assert the
   source dir-hashes match what that commit holds **and** match `registry.yaml`'s `sha256`, and (c)
   removing the false assurance of a recorded-but-unchecked hash. Fix: a CI job (or `update-check`
   extension) that makes `sha256_source` load-bearing, or drop the field.

2. **Update→pin gap: `update-check` can't tell you the SHA to pin.** `registry.yaml` carries `version` +
   `sha256` (content hash) but **no commit SHA**; `update-check.sh:58` tells the user to run
   `PLAYBOOK_REF=<new-sha>` with no SHA to copy. Fix: record the hub HEAD in `registry.yaml`
   (`build-registry.sh`), have `update-check` print the exact `PLAYBOOK_REF=<sha>`; optional `--open-pr`.

3. **Drift coverage gap + false-clean.** `drift-check` (a) prints "clean"/exit 0 on an empty-`skills`
   lockfile (verified in a scratch repo), and (b) silently skips any vendored skill not in the lockfile —
   `shadcn-svelte` and `svelte-core-bestpractices` are vendored under `.agents/skills/` but absent from the
   lockfile, so they get zero drift protection while the run still reports "clean." Fix: assert ≥1 skill
   checked; warn/fail on any `.agents/skills/*` dir with no lockfile entry (those two come from other
   upstreams and need their own sync/lock or an explicit ignore-list).

### MINOR (cheap hardening)

4. **Newline-in-filename corrupts the hash.** `find . -type f | LC_ALL=C sort | while read p` splits on
   newlines; a filename with a newline makes `sha256sum` miss and the dir-hash silently wrong. Fix:
   `find … -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p`. **Output-preserving** for all current
   (newline-free) names, so existing lock hashes don't change — but must be applied byte-identically to all
   copies (see #6).
5. **Command-substitution failure masked under `set -e`.** `sha_vendored="$(skill_dir_hash …)"` (`sync:97`)
   won't abort on an inner `sha256sum` failure (bash semantics). Fix: assert `[[ "$sha" =~ ^[0-9a-f]{64}$ ]]`
   before writing.
6. **Four/five `skill_dir_hash` copies kept identical by comment only.** Verified byte-identical *today*
   (all hash to `745b1e33…`), but no test guards it; editing one (e.g. to fix #4) silently diverges
   source≠vendored hashes. Fix: a test that diffs the function body across all copies (or factor into one
   sourced `lib.sh`).
7. **Unanchored registry grep in the validator.** `grep -q "sha256: $sha"` (`validate-skill.sh:89`) is a
   substring + regex-interpolated match. Fix: `grep -qxF "    sha256: $sha"`.
8. **`build-registry.sh` glob ordering not locale-pinned.** `for d in skills/*/` (`:29`) is governed by
   `LC_COLLATE`, unlike the `LC_ALL=C`-pinned hash; a non-C dev could regenerate a reordered registry that
   CI's `git diff --exit-code` then flags as stale. Fix: `export LC_ALL=C` at top.
9. **`check_registry_fresh` ignores `build-registry` exit code** (`validate-skill.sh:103`): a build failure
   compares stale-vs-stale and passes. Fix: check rc, `fail` on nonzero.

### Backlog / NIT (design or low-impact)
- Declarative skills manifest instead of the hand-edited `SKILLS=(...)` bash array (`sync:18`) — adopting a
  new skill is currently a code edit + the "(add to SKILLS)" two-step.
- `update-check --open-pr` (Renovate-style; safe because the resolved SHA still lands in the PR diff).
- Reject symlinks inside a vendored skill dir (`cp -R` copies them verbatim).
- Optional `git verify-commit` against a trusted key (pin gives immutability, not authenticity).
- Portability: hard-depends on GNU `sha256sum` / `sort -V` (document, or detect `shasum -a 256`).

## Panel claims NOT carried (verification rejected / corrected)
- "`pinned_sha` is dead data" (CI reviewer) — **corrected**: it *is* read at `sync:28` as the re-sync pin.
  Only `sha256_source` is write-only.
- "A full-SHA `checkout` isn't asserted == HEAD, enabling substitution" (supply-chain MAJOR #1) —
  **downgraded**: a full 40-hex SHA checkout is exact (fails if absent), and the stored pin is always the
  resolved full SHA. A cheap `resolved_sha == PLAYBOOK_REF` assert is still nice-to-have, but the
  substitution risk as stated is overstated. (Folded into the optional hardening, not a MAJOR.)
- "Short-SHA pin is weak" (DX MINOR) — **mostly already handled**: the *stored* pin is always the full
  `git rev-parse HEAD` (`:55,106`); only the *input* may be short.

## Disposition
Findings #1–#9 accepted as actionable. Awaiting human direction on scope before implementing (changes span
both repos; the contract files — CLAUDE.md/access.yaml/gates.yaml — are not touched by any of these).
