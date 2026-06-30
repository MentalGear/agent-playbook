#!/usr/bin/env bash
# Pins the single-source-of-truth invariant for skill_dir_hash: it is defined ONCE in lib.sh,
# no script inlines its own copy, and every script that needs it actually SOURCES lib.sh.
# (Replaces the old "5 byte-identical copies" guard.) Run: bash scripts/test/hash-consistency.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

# Tolerant function-definition detector: matches `skill_dir_hash() {`, `skill_dir_hash ()  {`,
# `skill_dir_hash {`, `function skill_dir_hash {`, and indented forms — so a re-inlined copy in
# any of those spellings is still caught.
DEF_RE='^[[:space:]]*(function[[:space:]]+)?skill_dir_hash[[:space:]]*(\([[:space:]]*\))?[[:space:]]*\{'
# Real source statement (`. …/lib.sh` or `source …/lib.sh`), NOT a mere mention in a comment.
SRC_RE='^[[:space:]]*(\.|source)[[:space:]].*lib\.sh'

echo "hash-consistency (single-source) tests:"

lib="$SRC/lib.sh"
defs="$(grep -cE "$DEF_RE" "$lib" 2>/dev/null || true)"
[ "${defs:-0}" -eq 1 ] && ok "lib.sh defines skill_dir_hash() exactly once" || no "lib.sh should define skill_dir_hash() once (found ${defs:-0})"

files=(sync-agent-skills.sh drift-check.sh build-registry.sh validate-skill.sh verify-pin.sh update-check.sh)
inline=0; unsourced=0
for f in "${files[@]}"; do
  p="$SRC/$f"
  [ -f "$p" ] || { no "$f: missing"; inline=1; continue; }
  if grep -qE "$DEF_RE" "$p"; then no "$f: inlines its own skill_dir_hash() — must source lib.sh instead"; inline=1; fi
  grep -qE "$SRC_RE" "$p" || { no "$f: has no '. …/lib.sh' source statement"; unsourced=1; }
done
[ "$inline" -eq 0 ]    && ok "no script inlines skill_dir_hash (single source lives in lib.sh)"
[ "$unsourced" -eq 0 ] && ok "every toolchain script sources lib.sh (real source statement, not a comment)"

echo "---"
echo "hash-consistency: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
