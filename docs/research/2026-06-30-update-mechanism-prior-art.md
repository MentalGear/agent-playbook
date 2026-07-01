# Prior art: how versioned, vendored content is distributed and updated

Date: 2026-06-30
Author: research agent (web + reasoning), with delegated sub-agents (Go/Cargo, Renovate/vendoring, TUF/Sigstore/SLSA)
Status: research capture to inform the hardening of `scripts/sync-agent-skills.sh` + `.agents/skills-lock.json` +
`scripts/drift-check.sh` + `scripts/update-check.sh` + the hub's `registry.yaml`.

## 0. The mechanism we are hardening (recap, so findings map cleanly)

A hub repo (`agent-playbook`) publishes versioned skill dirs. Consumers vendor selected skills into
`.agents/skills/<name>/`, pinned by the hub's git commit SHA in `.agents/skills-lock.json`. The lockfile stores
`playbook_repo`, `pinned_sha`, and per skill `{version, sha256_source, sha256_vendored}` (whole-dir hashes of the
source tree and the vendored copy respectively). `sync` clones the hub at the pin, copies dirs, writes the lock.
`drift-check` (pre-push + CI) recomputes vendored hashes vs the lock to catch hand-edits. `update-check` compares the
lock against the hub's generated `registry.yaml` (per-skill version + content sha256) and reports available updates
(advisory). Two open questions: **(1)** automate the *first* sync (resolve a default ref → concrete SHA → pin →
surface in the diff); **(2)** `update-check` names a newer version but `registry.yaml` carries no commit SHA to pin to.

---

## 1. Per-system table

| System | How it PINS | How it VERIFIES INTEGRITY | How it does FIRST-INSTALL | How it AUTOMATES UPDATES | ONE practice worth stealing |
|---|---|---|---|---|---|
| **Claude Code plugins / marketplaces** | Plugin `source` (`github`/`url`/`git-subdir`) takes optional `ref` (branch/tag) **and** `sha` (full 40-char commit); **when both set, `sha` is the effective pin** and is checked out directly. `version` string (in `marketplace.json` or `plugin.json`) gates updates; **omit it and the commit SHA becomes the version**. | None beyond git. Trust is by **source allowlist** (`strictKnownMarketplaces`, `blockedMarketplaces`) + curation of the official/community marketplaces; community plugins are "pinned to a specific commit SHA in the catalog." Explicit warning that Anthropic can't verify plugin contents. No signing/SRI. | `/plugin marketplace add owner/repo` then `/plugin install name@market`. A floating `ref` (or default branch) resolves at fetch time; the *catalog author* may also record an exact `sha`. No per-consumer lockfile — the marketplace `marketplace.json` IS the pin record. | Auto-update at startup (refresh catalog + bump installed plugins to latest matching version). **On by default for official Anthropic marketplaces; off by default for third-party/local.** Update is skipped if the resolved version equals the cached one. "Release channels" = two marketplaces pinned to different refs/SHAs assigned to user groups. | **The "version is optional, commit SHA is the fallback version" model** — exactly our situation. And: **`sha` overrides `ref`** so a deleted/moved tag still resolves (commit reachable). |
| **npm (package-lock.json v3)** | Per-package `version` + `resolved` (tarball URL, or `git+url#<full-commit-sha>` for git deps). | `integrity`: **SRI `sha512-…` of the tarball bytes**, verified before extract (`EINTEGRITY` on mismatch). Git deps record the resolved commit in `resolved`. | First `npm install` *writes* the lockfile (resolves ranges → concrete versions + records `resolved`+`integrity`). | `npm update` (within semver ranges) rewrites the lock; Renovate/Dependabot drive cross-range bumps. `npm ci` / `--frozen-lockfile` = install exactly the lock, fail if `package.json` and lock disagree (CI mode). | **`resolved` + `integrity` as two distinct fields**: a *locator* (where) and a *content digest* (what), verified at install. And **`ci` vs `install`**: a strict reproduce-only mode separate from a resolve-and-update mode. |
| **Cargo (Cargo.lock)** | Per-package `name`, `version`, `source`, `checksum`. | `checksum` = **SHA-256 of the crate**, cross-checked against the registry index; mismatch = detected tamper. Git deps pin a `rev`/commit in `source`. | First `cargo build` writes `Cargo.lock` (lockfile-on-first-build). Convention: **commit the lock for bins, not for libs.** | `cargo update` (rewrites lock within semver), `cargo update -p <crate>` (one crate). `--locked` (fail if lock would change) / `--frozen` (also offline). | **Lock-vs-index checksum threat model**: the lock's `checksum` exists specifically to detect a maliciously rewritten *index/registry* — a second, independent attestation of content beyond the source location. |
| **Go modules (go.sum + sumdb)** | `go.mod` requires `module vX.Y.Z`. A raw commit becomes a **pseudo-version** `vX.0.0-<yyyymmddhhmmss>-<12hexcommit>` (UTC commit time + 12-char commit hash) — a sortable, verifiable pin derived from the commit. | `go.sum` stores **`h1:` dirhash** (base64 SHA-256 of a manifest of per-file SHA-256 lines) for both the module zip and its `go.mod`. The **checksum database** (`sum.golang.org`, a Merkle transparency log) is consulted on first download; `GONOSUMCHECK`/`GONOSUMDB`/`GOPRIVATE`/`GOFLAGS=-mod=readonly` and `GOPROXY` tune fetch/verify. | First `go get`/`go mod tidy` resolves the version, **records `h1:` in `go.sum`, and on first sight verifies against sumdb (TOFU-with-witness)**. | `go get -u`, `go get pkg@latest`, `go mod tidy`. | **`h1:` dirhash = a deterministic whole-tree content hash** (manifest of sorted per-file hashes, then hash-of-hashes). This is *exactly* our `sha256_source`/`sha256_vendored` construction. Plus the **transparency-log "verify on first use" via a third party**. |
| **Renovate** | Can pin floating refs/tags to a **full commit digest** (`pinDigests`, `helpers:pinGitHubActionDigests`), keeping the human tag as a trailing comment. | Relies on the pinned digest (content-addressed) + ecosystem lock integrity. | n/a (operates on an existing repo). | **Pin-then-bump**: opens a *reviewable PR* that lands the resolved concrete version/SHA; configurable schedule, grouping, `separateMinorPatch`, automerge, dependency dashboard. | **"The resolved SHA lands in a reviewable diff a human approves."** The update *is* a PR — concrete, attributable, revertable. |
| **Dependabot** | Same digest-pinning for GitHub Actions; version bumps for package ecosystems. | Ecosystem lock integrity. | n/a. | Scheduled PRs; grouping. | Same as Renovate: **resolved pin in a reviewable PR**, plus first-class scheduling as a platform feature. |
| **vendir (carvel)** | `vendir.yml` declares sources (floating ref OK); **`vendir sync` resolves to a concrete commit and writes `vendir.lock.yml`** with `git: { sha, commitTitle }`. | The lock records a **git SHA pointer (content-addressed), not an independent content checksum of the synced tree**. GPG/signature verification is **opt-in**. | `vendir sync` resolves the ref → SHA, copies the tree in, writes the lock. `vendir sync -l` (locked) re-syncs exactly the lock for reproducibility. | Re-run `vendir sync` to bump; the new SHA shows in `vendir.lock.yml`'s git diff (because it's a tracked file — incidental, not a dedicated "resolution diff"). | **Exactly our shape**: floating spec (`vendir.yml`) + resolved lock (`vendir.lock.yml`) + a copy-the-tree sync + a `-l` locked mode. The closest single analogue to our mechanism. |
| **git submodules** | Commit SHA recorded as a **gitlink** (tree entry) in the superproject; `.gitmodules` holds URL+branch. | Git's own Merkle integrity (the gitlink IS a commit hash). | `git submodule add`/`update --init` checks out the recorded SHA. | `git submodule update --remote` moves the gitlink to the branch tip; the SHA change is a normal reviewable diff. | The pin is **a first-class tracked git object** (gitlink) — no separate lockfile needed; the commit *is* the lock. |
| **git subtree / git-vendor** | Pin lives in the **squash/merge commit metadata** (subtree) or commit-message trailers (git-vendor, a thin subtree wrapper under `vendor/<repo_uri>`). | Git Merkle integrity; no machine-readable lock. | `git subtree add --squash` vendors the tree at a commit. | `git subtree pull --squash`. | Vendoring the *content* into the repo (not a pointer) so consumers need no extra tooling — but pay with a weaker, non-machine-readable pin record. |
| **TUF** | n/a (a metadata framework over whatever artifacts). | Threshold-signed role metadata (root/targets/snapshot/timestamp) defends **rollback, freeze, mix-and-match, key compromise**; versioned + expiring metadata. | Ships a signed **root of trust** out-of-band (not TOFU). | Clients fetch timestamp→snapshot→targets and verify signatures. | The *threat vocabulary* (rollback / freeze / mix-and-match) is the useful export, not the machinery. |
| **Sigstore / cosign** | n/a. | **Keyless signing**: OIDC identity → Fulcio short-lived cert → signature → **Rekor transparency log**. Adds *authentication* (who) + *auditability* (when), on top of hash *integrity* (what). | n/a. | n/a. | If you ever need "*who* published this and prove it publicly," cosign/gitsign on a tag is the minimal form. |
| **SLSA / GitHub artifact attestations** | n/a. | `actions/attest-build-provenance` binds artifact digest → in-toto SLSA provenance, signed via Sigstore + the workflow's OIDC identity (repo/workflow/commit/runner claims). **SLSA Build L2 out of the box; L3 with the reusable workflow.** | n/a. | CI-emitted on release. | "Built by *this* workflow from *this* commit on a hosted runner" — a cheap provenance win **if** the threat model includes a compromised publisher. |

---

## 2. Best-practice synthesis (ranked, each tied to sources)

1. **Pin to a full commit SHA; the SHA is itself a content hash.** A git commit SHA is the root of a Merkle DAG over
   the tree, so pinning to a *full* 40-char SHA already gives strong tamper-evidence for free. Everyone serious does
   this: Claude Code (`sha` overrides `ref`), Go (pseudo-version embeds the commit), Renovate/Dependabot/GitHub
   hardening ("a full-length commit SHA is the only way to use an action as an immutable release"), submodules
   (gitlink), vendir (`vendir.lock.yml` `sha`). **Never pin to a short SHA or a movable tag as the source of truth.**
2. **Separate the *locator* from the *content digest*.** npm (`resolved` vs `integrity`), Cargo (`source` vs
   `checksum`), Go (module path/version vs `h1:`). The locator says *where/which*; the digest says *what*, and is
   verified independently. This is what catches a maliciously rewritten registry/index even when the locator looks
   right (Cargo's stated threat model).
3. **Whole-tree content hash = manifest of sorted per-file hashes, then hash that.** Go's `h1:` dirhash is precisely
   this construction, and it is what our `skill_dir_hash()` already does. It is the right, portable way to digest a
   directory of files (order-independent, rename-sensitive).
4. **Lockfile-on-first-install: resolve floating → concrete, then record it.** npm, Cargo, Go, and vendir all *write*
   the lock on first run by resolving a range/ref to a concrete pin. The human declares intent loosely; the tool
   commits the exact resolution. This is the direct answer to open question (1).
5. **The resolved pin lands in a reviewable diff.** vendir (`vendir.lock.yml` is tracked), submodules (gitlink), and
   especially Renovate/Dependabot (the update *is* a PR). The principle: a human reviews the concrete SHA change
   before it lands, and can revert it as one commit.
6. **Two modes: strict-reproduce vs resolve-and-update.** `npm ci`/`--frozen-lockfile`, `cargo --locked/--frozen`,
   `go -mod=readonly`, `vendir sync -l`. CI uses the strict mode (fail on any drift); developers use the resolving
   mode. Our `drift-check` is the strict mode; `sync` is the resolving mode — same split.
7. **Updates are advisory data + a deliberate adopt step; don't auto-mutate the pin.** Cargo/Go separate
   "what's available" (index/registry, `go list -m -u`) from "adopt it" (`cargo update`, `go get -u`). Renovate makes
   the adopt step a PR. Even Claude Code's auto-update is *opt-in per marketplace* and **off by default for
   third-party sources**. Auto-bumping a pin without review is the minority, higher-trust path.
8. **Trust = source allowlist + (optionally) a third-party verify-on-first-use.** Claude Code uses allowlists
   (`strictKnownMarketplaces`); Go adds the sumdb transparency log so the *first* fetch is checked against an
   independent witness, not blind TOFU. For a small internal hub, allowlist-of-one (the hub URL) + the lock is most of
   the value.
9. **Signing/provenance is an authentication+auditability layer *on top of* integrity, justified only by a publisher-
   compromise threat.** cosign/Rekor and SLSA attestations answer "*who* built/published this," which hashes alone
   don't. TUF's value for a tiny hub is its *threat vocabulary* (rollback/freeze/mix-and-match), not its machinery.

---

## 3. Concrete recommendations for OUR mechanism

Mapped to `scripts/sync-agent-skills.sh`, `.agents/skills-lock.json`, `scripts/update-check.sh`, `registry.yaml`.

### (a) First-install: is "default ref → resolve to SHA → pin → print" right? YES — and it's the mainstream pattern.

Adopt it. This is **exactly** what npm/Cargo/Go do on first install (resolve a range/ref, write the concrete pin to
the lock) and what **vendir** does (`vendir.yml` floating ref → `vendir sync` → concrete `sha` in `vendir.lock.yml`).
**vendir is the closest analogue and does precisely this.** Renovate does the PR-surfacing variant.

Concretely, change `sync-agent-skills.sh` so that when no pin is given:
- default `PLAYBOOK_REF` to `main` (a *floating* default ref) instead of erroring;
- resolve it to a concrete SHA with `git ls-remote "$PLAYBOOK_REPO" "$PLAYBOOK_REF"` (or `git rev-parse` after a
  shallow clone) **before** copying anything;
- write that concrete 40-char SHA as `pinned_sha`;
- **print the resolution explicitly** (`Resolved main → <sha>; pinned.`) and rely on the fact that
  `.agents/skills-lock.json` is a tracked file, so the new `pinned_sha` shows up in `git diff` for review — the same
  "incidental but sufficient" diff-surfacing vendir/submodules rely on.

Keep the existing safety: if an explicit `PLAYBOOK_REF` is given it must still win, and the local-checkout dirty/HEAD
mismatch guards stay. Only the *no-pin* path changes from "error" to "resolve default ref → pin → print."

> Who does *exactly* this: **vendir** (floating ref in `vendir.yml` → resolved `sha` in `vendir.lock.yml` on `sync`),
> **npm/Cargo/Go** (lockfile-on-first-install), **Renovate** (resolve → pin in a PR).

### (b) Should `registry.yaml` carry a commit SHA, and should the lock carry `resolved` + SRI `integrity`?

**Yes to a SHA in `registry.yaml` — this is the fix for open question (2).** Today `update-check` can name a newer
*version* but has no commit to pin to, so the human has to go hunting. Have the hub's registry generator record, per
skill, **the commit SHA at which that version was last changed** (e.g. `git log -1 --format=%H -- skills/<name>`),
emitting something like:

```yaml
subagent-framework:
  version: 1.1.0
  sha256: <whole-dir hash at that commit>
  commit: <full 40-char SHA where this version landed>   # NEW
```

Then `update-check` can print not just "`subagent-framework: 1.0.0 → 1.1.0`" but the **exact adopt command with a
concrete pin**: `PLAYBOOK_REF=<commit> scripts/sync-agent-skills.sh`. This mirrors Go's registry/sumdb carrying the
resolvable version and Cargo's index carrying the checksum to pin to.

**For the lockfile, add a `resolved` but treat SRI `integrity` as optional/redundant.** Borrow the npm
*locator-vs-digest* split in spirit:
- Add a per-skill `resolved` (or keep `pinned_sha` top-level and add nothing) — but note our `pinned_sha` already *is*
  the locator + a content commitment, because a git SHA is a Merkle root over the tree.
- An SRI-style `integrity: sha256-<base64>` field would be **mostly redundant** with `pinned_sha` for source integrity
  (the commit already binds the content). Its only marginal value is the npm/Cargo "detect a rewritten registry"
  case — i.e. detecting that the hub force-pushed a *different* tree onto the same-looking history. Our existing
  `sha256_source` already covers that. So: **don't add SRI `integrity`; you already have its equivalent.**

### (c) Is the `sha256_source` vs `sha256_vendored` split sound, or do mature tools do it differently?

**The split is sound and is *more* than most vendoring tools do — keep it.**
- `sha256_vendored` (recompute the local copy, compare to lock) is the **`drift-check` / `npm ci` / `cargo --locked`**
  equivalent — catches hand-edits to vendored files. This is the strongest part of your design and **vendir does NOT
  do it** (vendir's lock is a SHA *pointer*, with no independent content hash of the synced tree). You are ahead of
  vendir here.
- `sha256_source` is the Cargo "lock-vs-index checksum" / Go `h1:` equivalent — it lets you assert the vendored tree
  matches the hub tree at the pin, independent of the commit pointer. Worth keeping as the cross-check that turns
  "we pinned SHA X" into "and the bytes we copied are the bytes that SHA names."
- The hashing construction itself (`find -type f | sort | per-file sha256 | hash-of-hashes`) **is exactly Go's `h1:`
  dirhash** — the canonical correct way. The one caution mature tools encode: keep it byte-identical across
  `sync` / `build-registry` / `drift-check` (the script comment already says this) and beware
  platform-dependent file contents (npm has a known bug where git-dep integrity differed across architectures).

Net: your two-hash split is *better than* the median vendoring tool. No change needed except keeping the construction
canonical and documented.

### (d) Advisory update-check vs Renovate-style auto-PR — what's the norm?

**Advisory is the correct default for a hub like this; an opt-in auto-PR is a reasonable later add, not a requirement.**
- The package-manager norm (`cargo update`, `go get -u`) and even **Claude Code's own default for third-party
  marketplaces (auto-update OFF)** is: surface availability, let a human adopt deliberately. Your `update-check`
  being advisory-only (never fails the build) matches this exactly and is right.
- Renovate/Dependabot auto-PR is the norm *for large dependency graphs that change often*, where manual tracking
  doesn't scale. For ~7 vendored skills from one internal hub, that machinery is overkill.
- **Recommended middle path:** keep `update-check` advisory, and once (b) ships (registry carries `commit`), have it
  print a copy-pasteable `PLAYBOOK_REF=<commit> scripts/sync-agent-skills.sh`. Optionally add a tiny scheduled CI job
  (or a Renovate "custom manager"/regex manager later) that runs `update-check` and opens an issue/PR — so the
  *resolved SHA lands in a reviewable diff*, the principle worth stealing — but gate the actual pin bump on human
  review, never auto-merge.

### (e) Signing / provenance — worth it or overkill for a small internal hub? (tiered)

Reasoning from the fact that **a full git commit SHA is already a Merkle/content hash**: pinning to a full SHA +
recording `sha256_source`/`sha256_vendored` already gives you tamper-evidence and reproducibility. Signing adds
*authentication* (who) and *auditability* (when) — only valuable against a **publisher-compromise** threat.

- **Free / cheap wins — DO (mostly already done):**
  1. Pin to the **full 40-char** `pinned_sha` (not short) — content addressing for free.
  2. Keep `sha256_source` + `sha256_vendored` and the byte-identical dirhash.
  3. CI freshness assertion: the hub asserts `registry.yaml` is freshly generated; the consumer's `drift-check` runs
     in pre-push + CI. (Both already exist.)
  4. Resolve the default ref to a full SHA on first sync and commit it (rec (a)) — kills the "movable tag" weakness.
- **Low-cost optional — CONSIDER only if the threat model grows:**
  5. **Signed git tags** on the hub for each released registry version (`git tag -s`), so consumers *can* verify the
     tag was cut by a known maintainer key. Cheap, no infra.
  6. **GitHub artifact attestation** (`actions/attest-build-provenance`) on the generated `registry.yaml` — gets you
     SLSA Build L2 "this registry was built by this workflow from this commit" essentially for free in CI. Worth it
     only if you distribute `registry.yaml` as a built artifact rather than a committed file.
- **Overkill at this scale — DON'T:**
  7. Full **TUF** (root/targets/snapshot/timestamp, threshold keys, key ceremonies) — designed for public,
     high-value, many-publisher update systems; the operational cost dwarfs the benefit for one internal hub. *Steal
     its vocabulary* (guard against rollback/freeze by always pinning forward to a known-newer SHA and never silently
     accepting an older pin), not its machinery.
  8. **Rekor / keyless cosign / SLSA L3** — meaningful only with an external/untrusted publisher and a need for public
     transparency. Internal hub on trusted GitHub org: not justified.

**Bottom line on signing:** for this hub, the git SHA + content hashes you already have *are* the integrity story.
Add full-SHA pinning and the registry `commit` field first. Treat signed tags / attestations as a later, optional
authentication layer, and treat TUF/Rekor/SLSA-L3 as out of scope unless the trust boundary changes.

---

## 4. What we'd be missing vs best practice (gaps to consider)

1. **No registry `commit` field today → `update-check` can't hand back a pin.** This is open question (2); fix in (b).
2. **First sync errors instead of resolving a default ref.** Open question (1); fix in (a). Every mature tool
   resolves-and-records on first run.
3. **`pinned_sha` may be recorded short.** Confirm it's always the full 40-char SHA (GitHub hardening guidance:
   short SHAs/tags are not immutable). The current lockfile shows a full SHA — keep enforcing that.
4. **No `resolved` URL granularity per skill.** Minor: all skills come from one `playbook_repo` at one `pinned_sha`,
   so a top-level locator is fine. If skills ever come from *different* repos/pins, you'd need per-skill `resolved`
   like npm/vendir.
5. **No strict "ci" install mode flag distinct from sync.** `drift-check` covers the verify side, but there's no
   single `sync --locked` that *fails* if resolving would change the pin (vs silently re-pinning). Consider a
   `--locked` flag so CI can assert "the lock is authoritative; do not move it."
6. **No rollback guard.** Nothing currently prevents `update-check`/sync from accepting a pin that is *older* than the
   current one (TUF's "rollback attack"). For an internal hub this is low risk, but a one-line check that a new
   `pinned_sha` is a descendant of (or at least not an ancestor that lowers versions below) the current one would
   close it cheaply.
7. **No publisher authentication.** Acceptable at current trust level (see (e)); signed tags are the cheap upgrade if
   that changes.

---

## 5. Citations

Claude Code plugins / marketplaces:
- https://code.claude.com/docs/en/discover-plugins.md (install/update commands, auto-update defaults, "pinned to a
  specific commit SHA", security/trust model)
- https://code.claude.com/docs/en/plugin-marketplaces (plugin `source` `ref`/`sha` fields — "`sha` is the effective
  pin … even if the branch or tag … has since been deleted"; `version` optional, "Omit to fall back to the git
  commit SHA"; version resolution / release channels / update-detection)

npm:
- https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/ (`integrity` SRI sha512, `resolved`, lockfile
  purpose) — note: server intermittently 403s to automated fetch; corroborated via npm/cli issues #4263, #4460, #2846
- https://github.com/npm/cli/issues/2846 (git-dep integrity is architecture-sensitive — the dirhash caution)

Cargo:
- https://doc.rust-lang.org/cargo/reference/registry-index.html (registry index + checksum)
- https://github.com/rust-lang/cargo/issues/4800 (Cargo.lock `checksum` exists to detect a maliciously updated index)
- Cargo book on `--locked`/`--frozen` (strict/offline reproduce modes)

Go modules:
- https://go.dev/ref/mod (pseudo-versions `vX.0.0-yyyymmddhhmmss-abcdefabcdef`, `go.sum`, sumdb, GONOSUMDB/GOFLAGS/
  GOPRIVATE/GOPROXY, `-mod=readonly`)
- https://pkg.go.dev/golang.org/x/mod/sumdb/dirhash and https://github.com/andrew/dirhash (`h1:` = base64 SHA-256 of a
  manifest of per-file SHA-256 lines — the exact construction our `skill_dir_hash` uses)

Renovate / Dependabot:
- https://docs.renovatebot.com/ — `pinDigests`, `helpers:pinGitHubActionDigests` (pin floating ref → full digest,
  keep tag as comment; pin-then-bump; scheduling/grouping/automerge/dependency dashboard)
- https://docs.github.com/actions/security-for-github-actions/security-hardening-for-github-actions
  ("Pin actions to a full length commit SHA … currently the only way to use an action as an immutable release")

Git vendoring tools:
- https://carvel.dev/vendir/ (`vendir.yml` sources, `vendir sync`, `vendir.lock.yml` with `git: { sha, commitTitle }`,
  `sync -l` locked mode; GPG verification opt-in; lock is a SHA pointer, not an independent content checksum)
- https://git-scm.com/book/en/v2/Git-Tools-Submodules (gitlink pin, `submodule update --remote`)
- git subtree / git-vendor (pin lives in squash commit / commit-message trailers; no machine-readable lock)

Git as content-addressed Merkle DAG:
- https://git-scm.com/docs/hash-function-transition and https://graphite.com/guides/git-hash (a commit SHA is a
  Merkle root over the tree → pinning to a full SHA is tamper-evident "for free")

TUF / Sigstore / SLSA:
- https://theupdateframework.io/docs/security/ (rollback / freeze / mix-and-match / key-compromise threat model;
  role separation; signed root of trust vs TOFU)
- https://docs.sigstore.dev/cosign/signing/overview/ and https://github.com/sigstore/cosign (keyless signing: Fulcio
  short-lived certs + OIDC + Rekor transparency log; adds authentication + auditability over hash integrity)
- https://github.com/actions/attest-build-provenance and
  https://github.blog/.../enhance-build-security-and-reach-slsa-level-3-with-github-artifact-attestations/
  (in-toto SLSA provenance bound to artifact digest; Build L2 out of the box, L3 with reusable workflow)

## Unconfirmed / caveats
- npm v11 docs page intermittently returns HTTP 403 to automated fetch; the `integrity`/`resolved` field semantics
  were corroborated from npm/cli GitHub issues and the v6 docs rather than a clean v11 fetch.
- Renovate config option names (`pinDigests`, `helpers:pinGitHubActionDigests`) and the "pin then bump" behavior are
  reported from the delegated sub-agent's primary-source reading; spot-check against current Renovate docs before
  citing verbatim in code comments.
- vendir's "no independent content checksum of the synced tree" is high-confidence (read from a real `vendir.lock.yml`
  example + `sync.go`) but was not exhaustively verified across all source types (image/http sources may differ).
