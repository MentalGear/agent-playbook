#!/usr/bin/env bash
# registry.yaml merges as text, with no custom driver. Two branches that each edit a different skill
# must merge cleanly into a registry identical to one regenerated from the merged skills.
# Run: bash scripts/test/registry-merge.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

echo "registry-merge tests:"

if grep -qE '^[^#]*registry\.yaml.*[[:space:]]merge=' "$ROOT/.gitattributes" 2>/dev/null; then
  no ".gitattributes assigns registry.yaml a merge driver (it would run with only one side's skills on disk)"
else
  ok ".gitattributes assigns registry.yaml no merge driver"
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
w="$tmp/hub"
mkdir -p "$w"
# Copy the working tree, not a clone, so the test covers uncommitted changes too.
tar -C "$ROOT" --exclude=.git -cf - . | tar -C "$w" -xf -
g() { git -C "$w" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
g init -q -b main && g add -A && g commit -qm base

mapfile -t skills < <(cd "$w/skills" && ls -d */ | sed 's#/$##' | head -2)
edit() {  # branch, skill
  g checkout -q -b "$1" main
  echo "<!-- registry-merge test edit on $1 -->" >> "$w/skills/$2/SKILL.md"
  bash "$w/scripts/build-registry.sh" >/dev/null 2>&1 || { no "build-registry failed on branch $1"; return 1; }
  g add -A && g commit -qm "edit $2"
}
edit a "${skills[0]}" && edit b "${skills[1]}" || { echo "registry-merge: setup failed"; exit 1; }

g checkout -q b
if g merge -q --no-edit a >/dev/null 2>&1; then
  ok "two branches editing different skills merge cleanly"
  cp "$w/registry.yaml" "$tmp/merged.yaml"
  bash "$w/scripts/build-registry.sh" >/dev/null 2>&1
  if cmp -s "$tmp/merged.yaml" "$w/registry.yaml"; then
    ok "the text-merged registry.yaml equals one regenerated from the merged skills"
  else
    no "the text-merged registry.yaml differs from a regenerated one"
  fi
else
  no "two branches editing different skills conflicted in registry.yaml"
fi

echo "---"
echo "registry-merge: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
