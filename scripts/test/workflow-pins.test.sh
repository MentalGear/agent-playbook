#!/usr/bin/env bash
# Every workflow pins each action to a full commit SHA and declares its token permissions.
# A tag can be moved to other code; a SHA cannot. Run: bash scripts/test/workflow-pins.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

echo "workflow-pins tests:"
shopt -s nullglob
wfs=("$ROOT"/.github/workflows/*.yml "$ROOT"/.github/workflows/*.yaml)
[ "${#wfs[@]}" -gt 0 ] || { no "no workflow files found"; }
for wf in "${wfs[@]}"; do
  n="$(basename "$wf")"
  # `uses: owner/repo@ref` (local `./` actions and docker:// refs carry no tag to move).
  bad="$(grep -nE '^[[:space:]-]*uses:[[:space:]]*[^@[:space:]]+@' "$wf" \
         | grep -vE 'uses:[[:space:]]*(\./|docker://)' \
         | grep -vE '@[0-9a-f]{40}([[:space:]]|$)' || true)"
  [ -z "$bad" ] && ok "$n: every action is pinned to a 40-hex SHA" || no "$n: action not pinned to a SHA: $bad"
  grep -qE '^permissions:' "$wf" && ok "$n: declares top-level permissions" || no "$n: no top-level permissions block"
done

echo "---"
echo "workflow-pins: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
