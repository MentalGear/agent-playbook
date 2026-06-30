#!/usr/bin/env bash
# Pins the single-source-of-truth invariant for skill_dir_hash: it is defined ONCE in lib.sh,
# no script inlines its own copy, and every script that needs it sources lib.sh. (This replaces
# the old "5 byte-identical copies" guard — the copies are gone; the risk now is a stray re-inline
# or a script that forgets to source lib.sh.) Run: bash scripts/test/hash-consistency.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

echo "hash-consistency (single-source) tests:"

lib="$SRC/lib.sh"
defs="$(grep -c '^skill_dir_hash() {' "$lib" 2>/dev/null || true)"
[ "${defs:-0}" -eq 1 ] && ok "lib.sh defines skill_dir_hash() exactly once" || no "lib.sh should define skill_dir_hash() once (found ${defs:-0})"

# every script in the toolchain must source lib.sh and must NOT inline its own skill_dir_hash
files=(sync-agent-skills.sh drift-check.sh build-registry.sh validate-skill.sh verify-pin.sh update-check.sh)
inline=0; unsourced=0
for f in "${files[@]}"; do
  p="$SRC/$f"
  [ -f "$p" ] || { no "$f: missing"; inline=1; continue; }
  if grep -q '^skill_dir_hash() {' "$p"; then no "$f: inlines its own skill_dir_hash() — must source lib.sh instead"; inline=1; fi
  grep -q 'lib\.sh' "$p" || { no "$f: does not source lib.sh"; unsourced=1; }
done
[ "$inline" -eq 0 ]    && ok "no script inlines skill_dir_hash (single source lives in lib.sh)"
[ "$unsourced" -eq 0 ] && ok "every toolchain script sources lib.sh"

echo "---"
echo "hash-consistency: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
