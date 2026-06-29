#!/usr/bin/env bash
# Consumer-side drift check: have the vendored skills been hand-edited since sync?
# Recomputes each vendored SKILL.md's hash and compares it to .agents/skills-lock.json.
# Offline + fast — safe to wire into a pre-push / pre-commit hook. Exits non-zero on drift.
# Copy this into your repo at scripts/drift-check.sh alongside sync-agent-skills.sh.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/.agents/skills-lock.json"
[ -f "$lock" ] || { echo "drift-check: no lockfile ($lock) — run sync-agent-skills.sh first" >&2; exit 2; }

drift=0
# Each lockfile skill entry is one line: "<name>": { ... "sha256_vendored": "<hash>" }
while IFS= read -r line; do
  name="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\([A-Za-z0-9_-]*\)":[[:space:]]*{.*/\1/p')"
  [ -z "$name" ] && continue
  want="$(printf '%s' "$line" | sed -n 's/.*"sha256_vendored":[[:space:]]*"\([0-9a-f]*\)".*/\1/p')"
  f="$root/.agents/skills/$name/SKILL.md"
  if [ ! -f "$f" ]; then echo "  ✗ $name: vendored SKILL.md missing" >&2; drift=1; continue; fi
  have="$(sha256sum "$f" | cut -d' ' -f1)"
  if [ "$have" != "$want" ]; then
    echo "  ✗ $name: vendored SKILL.md was edited (hash mismatch). Don't hand-edit vendored skills —" >&2
    echo "      change upstream in agent-playbook and re-run sync-agent-skills.sh." >&2
    drift=1
  fi
done < <(grep '"sha256_vendored"' "$lock")

if [ "$drift" -ne 0 ]; then echo "drift-check: DRIFT detected." >&2; exit 1; fi
echo "drift-check: clean (vendored skills match the lockfile)."
