#!/usr/bin/env bash
# Tests for verify-pin.sh — makes sha256_source load-bearing (lockfile == hub@pin).
# Uses the offline AGENT_PLAYBOOK_SRC path against a local git fixture. The fixture lockfile names
# playbook_repo "x", so we set AGENT_PLAYBOOK_REPO=x to satisfy the canonical-hub anchor (and test
# the mismatch path separately). Run: bash scripts/test/verify-pin.test.sh
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

mkcons() {  # <pinned_sha> <sha256_source> [playbook_repo=x]
  local c; c="$(mktemp -d)"; mkdir -p "$c/scripts" "$c/.agents"
  cp "$SRC/lib.sh" "$SRC/verify-pin.sh" "$c/scripts/"
  printf '{\n  "playbook_repo": "%s",\n  "pinned_sha": "%s",\n  "skills": {\n    "foo": { "version": "1.0.0", "sha256_source": "%s", "sha256_vendored": "%s" }\n  }\n}\n' "${3:-x}" "$1" "$2" "$2" > "$c/.agents/skills-lock.json"
  echo "$c"
}

# 1) matching sha256_source verifies OK (exit 0)
c="$(mkcons "$pin" "$srch")"
( cd "$c" && AGENT_PLAYBOOK_SRC="$hub" AGENT_PLAYBOOK_REPO="x" bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "verify-pin OK when sha256_source matches hub@pin" || no "matching source hash should verify (exit 0)"
rm -rf "$c"

# 2) tampered sha256_source => exit 1 "does not match the hub" (NOT exit 2 "malformed")
c="$(mkcons "$pin" "0000000000000000000000000000000000000000000000000000000000000000")"
out="$(cd "$c" && AGENT_PLAYBOOK_SRC="$hub" AGENT_PLAYBOOK_REPO="x" bash scripts/verify-pin.sh 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && grep -qi "does not match the hub" <<<"$out"; } && ok "tampered sha256_source => exit 1 (does not match)" || no "tamper should be exit 1 + 'does not match' (rc=$rc): $out"
rm -rf "$c"

# 3) a local checkout that isn't at the lockfile pin => exit 2
c="$(mkcons "$(printf '%040d' 0)" "$srch")"
( cd "$c" && AGENT_PLAYBOOK_SRC="$hub" AGENT_PLAYBOOK_REPO="x" bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -eq 2 ] && ok "checkout not at the pin => exit 2" || no "pin != HEAD should be exit 2"
rm -rf "$c"

# 4) lockfile playbook_repo != expected hub => exit 2 (circular-trust anchor)
c="$(mkcons "$pin" "$srch" "https://evil.example/fork.git")"
out="$(cd "$c" && AGENT_PLAYBOOK_SRC="$hub" AGENT_PLAYBOOK_REPO="https://github.com/MentalGear/agent-playbook.git" bash scripts/verify-pin.sh 2>&1)"; rc=$?
{ [ "$rc" -eq 2 ] && grep -qi "!= expected" <<<"$out"; } && ok "playbook_repo mismatch => exit 2 (anchored to canonical hub)" || no "repo mismatch should be exit 2 (rc=$rc): $out"
# ...and overridable with VERIFY_PIN_ALLOW_REPO=1
( cd "$c" && AGENT_PLAYBOOK_SRC="$hub" VERIFY_PIN_ALLOW_REPO=1 bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "VERIFY_PIN_ALLOW_REPO=1 overrides the repo anchor" || no "override should verify OK"
rm -rf "$c"

# 5) clone-path failure: skips (exit 0) by default, FAILS (exit 1) under VERIFY_PIN_STRICT
c="$(mkcons "$pin" "$srch" "/nonexistent/repo.git")"
( cd "$c" && AGENT_PLAYBOOK_REPO="/nonexistent/repo.git" bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "unreachable hub skips (exit 0) by default" || no "offline should skip (exit 0)"
( cd "$c" && AGENT_PLAYBOOK_REPO="/nonexistent/repo.git" VERIFY_PIN_STRICT=1 bash scripts/verify-pin.sh >/dev/null 2>&1 ); [ $? -eq 1 ] && ok "VERIFY_PIN_STRICT=1 fails (exit 1) when the hub is unreachable" || no "strict mode should fail on unreachable hub"
rm -rf "$c"

rm -rf "$hub"
echo "---"
echo "verify-pin: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
