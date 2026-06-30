# Decision record: vendoring integrity — from hash-lock to a deterministic-sync git-diff gate

**Date:** 2026-06-30
**Status:** Adopted (pivot on `claude/update-mechanism-pivot`; the prior design is preserved on
`claude/hardened-stopped` for reference).

## Context

`agent-playbook` is a hub that publishes versioned, project-agnostic agent **skills** (markdown
directories). Consuming repos **vendor** selected skills — copy them in, pinned to a hub commit SHA — rather
than submodule them (the proven pattern for ephemeral fresh-clone web/sandbox containers, no submodule-init
or egress-proxy friction). The requirement: vendored skills must be **pinned** (reproducible) and
**tamper-evident** (a hand-edit to a vendored copy is caught), with a low-friction sync.

## What we initially built (the hash-based design)

Modeled on npm/Cargo/Go lockfiles, for defense-in-depth:

- A lockfile `.agents/skills-lock.json` with, per skill, a `version` **and two content hashes** —
  `sha256_source` (the hub's source dir) and `sha256_vendored` (the vendored copy, which differs by an
  injected provenance header).
- `drift-check.sh` — recompute the vendored dir-hash, compare to `sha256_vendored` (catch hand-edits);
  wired into the pre-push hook + CI.
- `verify-pin.sh` — re-fetch the hub at `pinned_sha`, recompute the source dir-hash, compare to
  `sha256_source` (tie the lockfile to the hub); strict mode in CI; repo-anchored to the canonical hub.
- A shared `lib.sh` (single `skill_dir_hash`, jq lockfile readers), a published `registry.yaml` +
  `update-check.sh`, and `validate-skill.sh` for the contribution path.

The reasoning was sound on paper, and the design was hardened across several review rounds (newline-safe
NUL-delimited hashing, jq parsing, an ancestry-free first-pin, a `verify-pin` trust anchor, etc.).

## What happened

We first asked **build-vs-buy**: no off-the-shelf tool covers the whole need — the closest, Carvel
**vendir**, has our exact shape (floating spec → resolved SHA in a lock → copy-tree → locked mode) but
**no independent content hash**, and it adds a Go binary to every consumer. So we kept the bash toolchain
and de-risked it (one sourced `lib.sh`, `jq` instead of `sed`/`grep`).

Then a **whole-system expert panel** (failure-mode, integration-lifecycle, design, and security lenses —
the earlier rounds had only reviewed diffs) found the hash design had **real, reproduced integrity holes**
*and* was over-built for the scope (~7 skills, one hub, a couple of consumers):

- **A — disconnected hashes (reproduced).** `sha256_source` (checked vs the hub) and `sha256_vendored`
  (what the agent actually loads) were **never compared to each other**, and nothing re-derived the vendored
  tree from the hub. Editing a vendored skill **and** updating its `sha256_vendored` passed *both*
  `drift-check` and `verify-pin` green — the malicious skill loads.
- **B — symlinks invisible.** The dir-hash used `find -type f`, so a symlink injected into a vendored skill
  (`→ /etc/passwd`) was undetected.
- **C — no prune.** Dropping a skill from `SKILLS` left an orphaned, still-loaded, no-longer-checked vendored
  dir + symlink; `drift-check` only *warned*, forever.
- **Over-built + mirroring liability.** Because `sync` is idempotent, `sync && git diff` already provides the
  guarantee; and the consumer's hand-mirrored script copies had nothing detecting hub↔consumer divergence.

## Why we changed direction

The key realization: **`sync` is deterministic**, so re-running it at the pinned SHA re-derives the vendored
tree from the hub and overwrites it. Therefore **`sync && git diff --exit-code` (in CI) is itself the
integrity check** — and a *stronger* one than the hashes, because it ties the vendored bytes back to the hub
on every run instead of to a self-declared lockfile field. One gate closes A (no hash to forge — git
re-derivation is the check), B (git tracks symlinks; `rm -rf` + re-copy removes an injected one), and C
(prune + the diff), while deleting the redundant `drift-check` + `verify-pin` + both hashes + the parsing
they needed. Smaller **and** more correct — the rare case where right-sizing and hardening point the same way.

## The decision

Replace the hash layer with:

- **Deterministic `sync-agent-skills.sh`** — vendor + provenance header + symlink, plus **prune** (skills no
  longer in `SKILLS`; `EXTERNAL_SKILLS` exempt), a **`git merge-base --is-ancestor`** check (reject a
  fork-only/off-branch pin; fail-closed when the default branch is unresolvable; `ALLOW_NONDEFAULT_PIN=1`
  overrides), **atomic** lockfile write, and a pre-validate pass.
- **Lockfile** = `{ playbook_repo, pinned_sha, skills:{name:version} }` — no content hashes.
- **CI gate** (consumer) = `sync-agent-skills.sh && git diff --exit-code -- .agents .claude` + **symlink
  hygiene** (no links under `.agents/skills`; every `.claude/skills` link points into `.agents/skills/`).
- **Kept** (separable concern): `update-check`, the `registry`/`validate`/`build-registry` publishing layer,
  and `jq`.

## Accepted boundaries / trade-offs

- **External skills** (vendored from *other* upstreams — e.g. shadcn-svelte, svelte-core-bestpractices) are
  **outside this gate's perimeter**: re-sync never touches them, so a malicious *content* edit is not caught
  by the gate (only symlink hygiene is). Verify them via their own upstream + PR review.
- **Offline pre-push integrity check dropped** — the gate needs network (to clone the hub), so it's CI-only.
- **Authenticity rests on the reviewed repo URL + ancestry within it**, not cryptographic provenance — the
  accepted posture for a small internal hub on a trusted GitHub org. No signing/TUF/Sigstore (researched and
  deemed overkill: a full-SHA pin + git re-derivation are the integrity story; signing only adds *who
  published it*).

## References

- Prior-art research: `SupraAppKit/docs/research/2026-06-30-update-mechanism-prior-art.md`
- First expert panel (on the hash design): `SupraAppKit/docs/research/2026-06-30-update-mechanism-review.md`
- The superseded hash-based design: branch `claude/hardened-stopped` (its README documents A/B/C at the top).
