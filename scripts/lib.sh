#!/usr/bin/env bash
# Shared helpers for the agent-playbook vendoring toolchain — the SINGLE source of truth.
# Source it (`. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"`); never copy these functions inline.
# Hard deps: bash, GNU coreutils (find -print0, sort -z, sha256sum), and jq (for lockfile reads).
#
# This file replaces (a) the five hand-synced copies of skill_dir_hash and (b) the brittle
# sed/grep parsing of .agents/skills-lock.json — both were repeated sources of review findings.

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

# Deterministic hash of ALL regular files in a skill dir (path+content). NUL-delimited so a
# filename containing a newline can't corrupt the file list. This is Go's `h1:` dirhash shape:
# a manifest of sorted per-file hashes, then a hash of that. Hashes regular files only (-type f);
# symlinks are not covered.
skill_dir_hash() {
  ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

# --- Lockfile (.agents/skills-lock.json) readers — jq, not sed/grep ----------------------------
lock_pin()  { jq -r '.pinned_sha   // ""' "$1"; }   # the pinned commit SHA
lock_repo() { jq -r '.playbook_repo // ""' "$1"; }   # the hub repo URL
# One TSV row per skill: name<TAB>version<TAB>sha256_source<TAB>sha256_vendored
lock_skills() {
  jq -r '.skills | to_entries[]
         | [ .key, (.value.version//""), (.value.sha256_source//""), (.value.sha256_vendored//"") ]
         | @tsv' "$1"
}
