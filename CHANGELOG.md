# Changelog

Consumer-facing changes to the playbook. **Written for the agent doing the upgrade**, not for a release
announcement: each entry says what changed and, where it matters, what the consuming repo must *do*.

## How an agent uses this

Entries carry the hub commit they landed in. When bumping a pin, read every entry whose commit is newer
than your `.agents/skills-lock.json` pin and act on each **`ACTION REQUIRED`** line. `update-check.sh`
does this for you — it prints the action-required entries between your pin and upstream.

**`ACTION REQUIRED` is a literal, greppable marker.** Anything an upgrade must change in the consuming
repo carries it. An entry without one is safe to adopt by re-syncing and nothing else.

> **Always re-copy `scripts/sync-agent-skills.sh` + `scripts/lib.sh` when you bump the pin.** The sync
> script is vendored, so hub changes to what it generates are inert until you re-copy it. Since v2 the
> script detects this itself and refuses; before v2 it fails *silently*, which is why this line is here.

---

## 2026-09-14 — `96f7371` Routing-index cost measured

- Adds `scripts/measure-index-overhead.sh`, an instrument: is the route index earning its always-loaded
  context? At 11 skills the routes are **+26% additive overhead** in a harness that preloads skill
  descriptions natively (Claude Code does), returning nothing that harness did not already have.
- The standing-rules section is unaffected — no skill description carries a standing rule, so it has no
  other channel. Kill criteria for the routes section are recorded in
  `docs/decisions/2026-09-14-routing-index-evidence.md`.
- No consumer action. The routes are not retired; budget is simply no longer a reason to keep them.

## 2026-09-14 — `9beb22b` Stale-script detection + trigger-collision warnings

- **`SYNC_SCRIPT_VERSION` (now 2).** `sync-agent-skills.sh` compares itself against the hub's copy at the
  pinned SHA and **refuses, before touching the vendored tree**, if yours is older. `ALLOW_STALE_SYNC_SCRIPT=1`
  overrides. The lockfile records the version.
- **ACTION REQUIRED (only if your script predates v2):** re-copy the script. A pre-v2 script run against
  this hub deletes your generated rules file, writes no replacement, and **exits 0** — no warning, and the
  integrity gate stays clean. Nothing we ship can warn you about this; that is what this entry is for.
  ```
  cp <hub>/scripts/sync-agent-skills.sh <hub>/scripts/lib.sh scripts/   # then restore your SKILLS=(…) list
  ```
- Near-duplicate routing triggers now warn (never fail) in both `sync` and `validate-skill`.
- `review-skill-proposal` 1.2.0 → 1.3.0: sharper opener, no behaviour change.

## 2026-09-14 — `88c0b58` (#17) Rule index replaces the per-skill hint field

- `.agents/AGENT_RULES.md` replaces `.agents/GLOBAL_HINTS.md`. Two sections: **standing rules** (verbatim,
  self-contained) and **routes** (one derived trigger per vendored skill).
- The routing trigger is **derived** from each skill's `description` first sentence — the
  `global_agent_file_hint` frontmatter field, a separate `when:` field, and per-skill `agent-rules.md`
  files are all gone. `validate-skill.sh` rejects each with a migration message.
- **ACTION REQUIRED:** change your `CLAUDE.md` import line.
  ```diff
  - @.agents/GLOBAL_HINTS.md
  + @.agents/AGENT_RULES.md
  ```
  A current sync deletes the stale `GLOBAL_HINTS.md` and prints a `MIGRATION:` notice; it cannot edit your
  `CLAUDE.md`.
- `subagent-framework` 1.3.0 (model-tier selection, resource serialization),
  `agent-operating-principles` 2.1.0 (challenge a proposal before building it).
- `avoid-dense-prose` **removed** — subsumed by the standing rule "write in standard technical English",
  which is always loaded rather than needing a skill load first.
- **ACTION REQUIRED (if you vendored it):** drop `avoid-dense-prose` from your `SKILLS=(…)` list. Sync
  fails on a skill missing upstream.

## 2026-09-14 — `7738540` (#18) `avoid-dense-prose` added

Added, then retired in #17 above. Do not vendor it.

## 2026-09-13 — `31c6290` (#15) Working-rules set ported

Three new skills — `solve-by-construction`, `verification-instruments`, `salvage-subagent-transcript` —
and extensions to six existing ones. Additive; no consumer action beyond adding any you want to
`SKILLS=(…)`.

## 2026-08-28 — `beeb269` (#13) Standing-rules channel (superseded)

Introduced `global_agent_file_hint` and `.agents/GLOBAL_HINTS.md`. **Superseded by #17** — if you are
upgrading from a pin at or before this commit, follow #17's action items and skip this one.

## 2026-07 — `aba2c78` (#6) Deterministic sync + integrity gate

Vendoring became deterministic: re-running sync at the pinned SHA reproduces the tree byte-for-byte.

- **ACTION REQUIRED:** the integrity gate is a re-sync plus `git status --porcelain -- .agents .claude`
  — **not** `git diff --exit-code`, which ignores untracked files and misses an orphaned skill directory.
  ```yaml
  - run: scripts/sync-agent-skills.sh && git status --porcelain -- .agents .claude
  ```
