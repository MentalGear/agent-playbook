#!/usr/bin/env bash
# Shared helpers for the agent-playbook vendoring toolchain — the SINGLE source of truth.
# Source it (`. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"`); never copy these functions inline.
# Hard deps: bash, GNU coreutils, and jq (for lockfile reads). skill_dir_hash is used by the hub's
# build-registry/validate-skill (the published registry's content hash); the consumer's integrity
# gate is sync + `git status --porcelain` (not `git diff`, which ignores untracked files), not a hash.

# Fail loudly if a required tool is absent (better than silently mis-parsing / wrong hashes).
require_tools() {
  local t missing=()
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: missing required tool(s): ${missing[*]}" >&2
    case " ${missing[*]} " in
      *" jq "*) echo "  jq is required for lockfile parsing — install it (apt: jq · brew: jq · https://jqlang.github.io/jq/)" >&2 ;;
    esac
    exit 3
  fi
}

# Deterministic hash of ALL regular files in a skill dir (path+content) — used by build-registry.sh
# / validate-skill.sh for the registry's published sha256. Go's `h1:` dirhash shape; NUL-delimited
# so a filename with a newline can't corrupt the file list. Hashes regular files only (-type f).
skill_dir_hash() {
  ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

# --- Lockfile (.agents/skills-lock.json) readers — jq, not sed/grep ----------------------------
# `// ""` coalesces a missing field to empty ON PURPOSE: an empty pin fails the 40-char-SHA regex in
# sync, so the downstream checks are the real gate. Don't "simplify" those checks away.
lock_pin()  { jq -r '.pinned_sha   // ""' "$1"; }   # the pinned commit SHA
lock_repo() { jq -r '.playbook_repo // ""' "$1"; }   # the hub repo URL
# One row per skill: name<US>version, joined by US (0x1f, ASCII unit separator). Read with
# `IFS=$'\x1f' read -r name ver`. US is deliberately NOT a tab (tab is IFS-whitespace, which would
# collapse an empty field and shift columns); US is non-whitespace, so empty fields are preserved.
# `(.skills // {})` so a lockfile missing the skills key yields zero rows instead of a raw jq error.
# Lockfile skills values are version strings — no content hashes (sync + git diff is the gate).
lock_skills() {
  jq -r '(.skills // {}) | to_entries[] | [ .key, (.value // "") ] | join("\u001f")' "$1"
}
