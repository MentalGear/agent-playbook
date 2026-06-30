#!/usr/bin/env bash
# Tests for verify-pin.sh — makes sha256_source load-bearing (lockfile == hub@pin).
# Uses the offline AGENT_PLAYBOOK_SRC path against a local git fixture. Run:
#   bash scripts/test/verify-pin.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }
dirhash() { ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
  printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 ); }

echo "verify-pin tests:"

# a hub at one commit, with a multi-file skill
hub="$(mktemp -d)"; mkdir -p "$hub/skills/foo"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hub/skills/foo/SKILL.md"
printf 'ref\n' > "$hub/skills/foo/reference.md"
( cd "$hub" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm init )
pin="$(git -C "$hub" rev-parse HEAD)"
srch="$(dirhash "$hub/skills/foo")"

mkcons() {  # <pinned_sha> <sha256_source>
  local c; c="$(mktemp -d)"; mkdir -p "$c/scripts" "$c/.agents"
  cp "$SRC/verify-pin.sh" "$c/scripts/"
  printf '{\n  "playbook_repo": "x",\n  "pinned_sha": "%s",\n  "skills": {\n    "foo": { "version": "1.0.0", "sha256_source": "%s", "sha256_vendored": "%s" }\n  }\n}\n' "$1" "$2" "$2" > "$c/.agents/skills-lock.json"
  echo "$c"
}

# 1) matching sha256_source verifies OK against the hub at the pin
c="$(mkcons "$pin" "$srch")"
( cd "$c" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "verify-pin OK when lockfile sha256_source matches hub@pin" || no "matching source hash should verify"
rm -rf "$c"

# 2) tampered sha256_source is caught (lockfile claims a hash the hub doesn't produce)
c="$(mkcons "$pin" "0000000000000000000000000000000000000000000000000000000000000000")"
( cd "$c" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -ne 0 ] && ok "verify-pin FAILS on a tampered sha256_source" || no "wrong source hash should fail"
rm -rf "$c"

# 3) a local checkout that isn't at the lockfile pin is rejected
c="$(mkcons "$(printf '%040d' 0)" "$srch")"
( cd "$c" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -ne 0 ] && ok "verify-pin rejects a checkout that isn't at the pin" || no "pin != HEAD should fail"
rm -rf "$c"

rm -rf "$hub"
echo "---"
echo "verify-pin: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
