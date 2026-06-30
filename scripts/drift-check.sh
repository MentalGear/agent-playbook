#!/usr/bin/env bash
# Consumer-side drift check: have the vendored skills been hand-edited since sync?
# Recomputes each vendored skill's WHOLE-DIR hash (SKILL.md + reference.md + assets)
# and compares it to .agents/skills-lock.json. Offline + fast — safe to wire into a
# pre-push / pre-commit hook. Exits non-zero on drift.
# Copy this into your repo at scripts/drift-check.sh alongside sync-agent-skills.sh + lib.sh.
set -uo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" || { echo "drift-check: cannot source lib.sh" >&2; exit 3; }
require_tools jq
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/.agents/skills-lock.json"
[ -f "$lock" ] || { echo "drift-check: no lockfile ($lock) — run sync-agent-skills.sh first" >&2; exit 2; }

# Reject a lockfile that isn't valid JSON (jq would emit nothing and the loop would run zero
# times → a false 'clean'). Fail loudly instead.
jq -e . "$lock" >/dev/null 2>&1 || { echo "drift-check: $lock is not valid JSON." >&2; exit 2; }

drift=0; checked=0; tracked=""
# name<US>version<US>sha256_source<US>sha256_vendored  (jq + US separator; see lib.sh lock_skills)
while IFS=$'\x1f' read -r name _ver _src want; do
  [ -z "$name" ] && continue
  tracked="$tracked $name"
  d="$root/.agents/skills/$name"
  if [ ! -f "$d/SKILL.md" ]; then echo "  ✗ $name: vendored skill missing" >&2; drift=1; checked=$((checked+1)); continue; fi
  have="$(skill_dir_hash "$d")"
  if [ "$have" != "$want" ]; then
    echo "  ✗ $name: vendored skill was edited (dir-hash mismatch). Don't hand-edit vendored skills —" >&2
    echo "      change upstream in agent-playbook and re-run sync-agent-skills.sh." >&2
    drift=1
  fi
  checked=$((checked+1))
done < <(lock_skills "$lock")

# A lockfile that parses to zero skills must NOT pass as "clean" (empty/truncated skills map).
if [ "$checked" -eq 0 ]; then
  echo "drift-check: no skills in $lock — empty or malformed lockfile. Refusing a false 'clean'." >&2
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
