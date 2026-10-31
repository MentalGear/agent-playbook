#!/usr/bin/env bash
# One home per artifact: agent-repo-layout's tree is the only place that defines a docs/ folder. Every
# docs/<folder>/ that any skill names, and every folder this hub keeps under docs/, must be in that tree,
# so a skill cannot send an artifact to a home the layout does not define.
# Run: bash scripts/test/layout-homes.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

echo "layout-homes tests:"
layout="$ROOT/skills/agent-repo-layout/SKILL.md"
# Folders under "docs/" in the first fenced block after "## Standard layout".
homes="$(awk '/^## Standard layout/{s=1} s&&/^```/{n++; if(n==2) exit; next} s&&n==1' "$layout" \
  | awk '/^docs\/$/{d=1; next} /^[^ ]/{d=0} d&&/^  [a-z0-9-]+\//{f=$1; sub(/\/.*/,"",f); print f}' | sort -u)"
[ -n "$homes" ] && ok "read the docs/ homes from agent-repo-layout: $(echo $homes)" || no "could not read the layout tree"

named="$(grep -rhoE 'docs/[a-z0-9-]+/' "$ROOT/skills" | sed 's#^docs/##; s#/$##' | sort -u)"
missing=""; for f in $named; do grep -qxF "$f" <<<"$homes" || missing="$missing $f"; done
[ -z "$missing" ] && ok "every docs/ folder a skill names is a layout home" || no "skills name docs/ folders the layout does not define:$missing"

kept="$(cd "$ROOT/docs" 2>/dev/null && ls -d */ 2>/dev/null | sed 's#/$##')"
missing=""; for f in $kept; do grep -qxF "$f" <<<"$homes" || missing="$missing $f"; done
[ -z "$missing" ] && ok "every folder this hub keeps under docs/ is a layout home" || no "hub docs/ folders missing from the layout:$missing"

echo "---"
echo "layout-homes: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
