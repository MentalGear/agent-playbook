#!/usr/bin/env bash
# Consumer-side drift check: have the vendored skills been hand-edited since sync?
# Recomputes each vendored skill's WHOLE-DIR hash (SKILL.md + reference.md + assets)
# and compares it to .agents/skills-lock.json. Offline + fast — safe to wire into a
# pre-push / pre-commit hook. Exits non-zero on drift.
# Copy this into your repo at scripts/drift-check.sh alongside sync-agent-skills.sh.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/.agents/skills-lock.json"
[ -f "$lock" ] || { echo "drift-check: no lockfile ($lock) — run sync-agent-skills.sh first" >&2; exit 2; }

# Deterministic hash of ALL files in a skill dir (path+content). MUST stay byte-identical
# to sync-agent-skills.sh / build-registry.sh / validate-skill.sh, or hashes will disagree.
# (NUL-delimited so filenames containing newlines can't corrupt the file list.)
skill_dir_hash() {
  ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

drift=0; checked=0; tracked=""
# Each lockfile skill entry is one line: "<name>": { ... "sha256_vendored": "<hash>" }
while IFS= read -r line; do
  name="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\([A-Za-z0-9_-]*\)":[[:space:]]*{.*/\1/p')"
  [ -z "$name" ] && continue
  tracked="$tracked $name"
  want="$(printf '%s' "$line" | sed -n 's/.*"sha256_vendored":[[:space:]]*"\([0-9a-f]*\)".*/\1/p')"
  d="$root/.agents/skills/$name"
  if [ ! -f "$d/SKILL.md" ]; then echo "  ✗ $name: vendored skill missing" >&2; drift=1; continue; fi
  have="$(skill_dir_hash "$d")"
  if [ "$have" != "$want" ]; then
    echo "  ✗ $name: vendored skill was edited (dir-hash mismatch). Don't hand-edit vendored skills —" >&2
    echo "      change upstream in agent-playbook and re-run sync-agent-skills.sh." >&2
    drift=1
  fi
  checked=$((checked+1))
done < <(grep '"sha256_vendored"' "$lock")

# A lockfile that parses to zero skills must NOT pass as "clean" (truncated/malformed JSON, a
# reformat that broke the one-entry-per-line shape, or a renamed field). Fail, don't false-clear.
if [ "$checked" -eq 0 ]; then
  echo "drift-check: no skills parsed from $lock — malformed lockfile or zero entries. Refusing a false 'clean'." >&2
  exit 2
fi

# Surface vendored skill dirs NOT tracked by this lockfile — they get NO drift protection here
# (e.g. skills vendored from a different upstream). Warn, don't fail: they may be managed
# elsewhere. The point is to end the silent false reassurance, not to break legitimate setups.
if [ -d "$root/.agents/skills" ]; then
  for d in "$root"/.agents/skills/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    case " $tracked " in
      *" $n "*) : ;;
      *) echo "  ! $n: vendored under .agents/skills/ but absent from the lockfile — no drift protection from this lockfile." >&2 ;;
    esac
  done
fi

if [ "$drift" -ne 0 ]; then echo "drift-check: DRIFT detected." >&2; exit 1; fi
echo "drift-check: clean ($checked tracked skill(s) match the lockfile)."
