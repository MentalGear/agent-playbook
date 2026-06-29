#!/usr/bin/env bash
# Dependency-free tests for the consumer toolchain: sync-agent-skills.sh + drift-check.sh.
# Each case pins a review-panel finding. Run: bash scripts/test/sync-drift.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

# same dir-hash formula as the scripts (to build expected lockfile values)
dirhash() { ( cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r p; do
  printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 ); }

mkconsumer() {  # a consumer with one vendored multi-file skill + a matching lockfile
  local c; c="$(mktemp -d)"; mkdir -p "$c/scripts" "$c/.agents/skills/foo"
  cp "$SRC/drift-check.sh" "$c/scripts/"
  printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$c/.agents/skills/foo/SKILL.md"
  printf 'reference content\n' > "$c/.agents/skills/foo/reference.md"
  local h; h="$(dirhash "$c/.agents/skills/foo")"
  printf '{\n  "playbook_repo": "x",\n  "pinned_sha": "deadbeef",\n  "skills": {\n    "foo": { "version": "1.0.0", "sha256_source": "%s", "sha256_vendored": "%s" }\n  }\n}\n' "$h" "$h" > "$c/.agents/skills-lock.json"
  echo "$c"
}

echo "drift-check + sync tests:"

# 1) clean tree passes
c="$(mkconsumer)"
( cd "$c" && bash scripts/drift-check.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "drift-check clean on untouched tree" || no "should be clean"
# 2) editing reference.md (NOT SKILL.md) is detected — the whole-dir coverage fix
echo "tampered" >> "$c/.agents/skills/foo/reference.md"
( cd "$c" && bash scripts/drift-check.sh >/dev/null 2>&1 ); [ $? -ne 0 ] && ok "drift-check detects a reference.md edit (whole-dir)" || no "reference.md edit should be drift"
rm -rf "$c"
# 3) missing skill is flagged
c="$(mkconsumer)"; rm -f "$c/.agents/skills/foo/SKILL.md"
( cd "$c" && bash scripts/drift-check.sh >/dev/null 2>&1 ); [ $? -ne 0 ] && ok "drift-check flags a missing skill" || no "missing skill should fail"
rm -rf "$c"

# 4) sync pin-honesty: explicit PLAYBOOK_REF != local SRC HEAD must hard-error
hub="$(mktemp -d)"; mkdir -p "$hub/scripts" "$hub/skills/foo"
cp "$SRC/sync-agent-skills.sh" "$SRC/build-registry.sh" "$hub/scripts/"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hub/skills/foo/SKILL.md"
( cd "$hub" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm init )
cons="$(mktemp -d)"; mkdir -p "$cons/scripts"; cp "$SRC/sync-agent-skills.sh" "$cons/scripts/"
out="$(cd "$cons" && SKILLS=(foo) PLAYBOOK_REF=0000000000000000000000000000000000000000 AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
# note: SKILLS is set inside the script; override via env won't apply, so just assert the pin guard fires
{ [ $rc -ne 0 ] && grep -qi "disagrees with local checkout" <<<"$out"; } && ok "sync hard-errors on explicit pin != SRC HEAD" || no "sync should reject mismatched explicit pin (rc=$rc): $out"

# 5) sync whole-dir lockfile: sha256_vendored covers reference.md
printf 'ref\n' > "$hub/skills/foo/reference.md"
( cd "$hub" && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm ref )
cons2="$(mktemp -d)"; mkdir -p "$cons2/scripts"
cp "$SRC/sync-agent-skills.sh" "$SRC/build-registry.sh" "$cons2/scripts/"
# patch SKILLS list in the copied script to just our fixture skill
sed -i 's/^SKILLS=(.*)$/SKILLS=(foo)/' "$cons2/scripts/sync-agent-skills.sh"
hubsha="$(git -C "$hub" rev-parse HEAD)"
( cd "$cons2" && PLAYBOOK_REF="$hubsha" AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
locked="$(sed -n 's/.*"foo":.*"sha256_vendored":[[:space:]]*"\([0-9a-f]*\)".*/\1/p' "$cons2/.agents/skills-lock.json")"
expect="$(dirhash "$cons2/.agents/skills/foo")"
[ -n "$locked" ] && [ "$locked" = "$expect" ] && ok "sync lockfile sha256_vendored is the whole-dir hash" || no "lockfile vendored hash should equal dir-hash (locked=$locked expect=$expect)"
rm -rf "$hub" "$cons" "$cons2"

echo "---"
echo "sync-drift: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
