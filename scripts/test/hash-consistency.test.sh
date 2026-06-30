#!/usr/bin/env bash
# Pins the invariant that the inlined skill_dir_hash() function is BYTE-IDENTICAL across every
# script that computes it. If one copy drifts (e.g. someone fixes a bug in only one), source and
# vendored hashes silently disagree across the toolchain — drift-check screams false drift, or
# worse agrees by coincidence. This test extracts each copy's function body and asserts equality.
# Run: bash scripts/test/hash-consistency.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

# Every script that inlines skill_dir_hash(). Add new copies here.
files=(sync-agent-skills.sh drift-check.sh build-registry.sh validate-skill.sh verify-pin.sh)
extract() { awk '/^skill_dir_hash\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$1"; }

echo "hash-consistency tests:"
ref=""; refname=""; mismatch=0; present=0
for f in "${files[@]}"; do
  path="$SRC/$f"
  [ -f "$path" ] || { no "$f: missing"; mismatch=1; continue; }
  body="$(extract "$path")"
  [ -n "$body" ] || { no "$f: no skill_dir_hash() body found"; mismatch=1; continue; }
  present=$((present+1))
  if [ -z "$ref" ]; then ref="$body"; refname="$f"
  elif [ "$body" != "$ref" ]; then no "$f: skill_dir_hash() body differs from $refname"; mismatch=1; fi
done
{ [ "$present" -ge 2 ] && [ "$mismatch" -eq 0 ]; } \
  && ok "skill_dir_hash() byte-identical across $present copies" \
  || no "skill_dir_hash() copies diverged or too few found (present=$present)"

echo "---"
echo "hash-consistency: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
