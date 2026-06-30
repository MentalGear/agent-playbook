#!/usr/bin/env bash
# Dependency-free tests for the consumer toolchain: sync-agent-skills.sh + drift-check.sh.
# Each case pins a review-panel finding. Run: bash scripts/test/sync-drift.test.sh
# (Scripts source lib.sh, so every fixture copies lib.sh alongside them.)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

# same dir-hash formula as lib.sh (to build expected lockfile values)
dirhash() { ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
  printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 ); }

# copy lib.sh + the named scripts into <dir>/scripts/
putscripts() { local dst="$1"; shift; mkdir -p "$dst/scripts"; cp "$SRC/lib.sh" "$@" "$dst/scripts/"; }

mkconsumer() {  # a consumer with one vendored multi-file skill + a matching lockfile
  local c; c="$(mktemp -d)"; mkdir -p "$c/.agents/skills/foo"
  putscripts "$c" "$SRC/drift-check.sh"
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
hub="$(mktemp -d)"; mkdir -p "$hub/skills/foo"; putscripts "$hub" "$SRC/sync-agent-skills.sh" "$SRC/build-registry.sh"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hub/skills/foo/SKILL.md"
( cd "$hub" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm init )
cons="$(mktemp -d)"; putscripts "$cons" "$SRC/sync-agent-skills.sh"
out="$(cd "$cons" && PLAYBOOK_REF=0000000000000000000000000000000000000000 AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi "disagrees with local checkout" <<<"$out"; } && ok "sync hard-errors on explicit pin != SRC HEAD" || no "sync should reject mismatched explicit pin (rc=$rc): $out"

# 5) sync whole-dir lockfile: sha256_vendored covers reference.md
printf 'ref\n' > "$hub/skills/foo/reference.md"
( cd "$hub" && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm ref )
cons2="$(mktemp -d)"; putscripts "$cons2" "$SRC/sync-agent-skills.sh" "$SRC/build-registry.sh"
sed -i 's/^SKILLS=(.*)$/SKILLS=(foo)/' "$cons2/scripts/sync-agent-skills.sh"
hubsha="$(git -C "$hub" rev-parse HEAD)"
( cd "$cons2" && PLAYBOOK_REF="$hubsha" AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
locked="$(jq -r '.skills.foo.sha256_vendored' "$cons2/.agents/skills-lock.json")"
expect="$(dirhash "$cons2/.agents/skills/foo")"
[ -n "$locked" ] && [ "$locked" = "$expect" ] && ok "sync lockfile sha256_vendored is the whole-dir hash" || no "lockfile vendored hash should equal dir-hash (locked=$locked expect=$expect)"
rm -rf "$hub" "$cons" "$cons2"

# 6) drift-check refuses a false 'clean' on a zero-entry lockfile (panel: false-clean gate)
c="$(mktemp -d)"; mkdir -p "$c/.agents/skills"; putscripts "$c" "$SRC/drift-check.sh"
printf '{\n  "playbook_repo": "x",\n  "pinned_sha": "deadbeef",\n  "skills": {}\n}\n' > "$c/.agents/skills-lock.json"
( cd "$c" && bash scripts/drift-check.sh >/dev/null 2>&1 ); [ $? -ne 0 ] && ok "drift-check refuses false-clean on an empty lockfile" || no "empty lockfile must not pass as clean"
rm -rf "$c"

# 6b) drift-check refuses a false 'clean' on a non-JSON lockfile (jq validity gate)
c="$(mktemp -d)"; mkdir -p "$c/.agents/skills"; putscripts "$c" "$SRC/drift-check.sh"
printf 'not json at all\n' > "$c/.agents/skills-lock.json"
( cd "$c" && bash scripts/drift-check.sh >/dev/null 2>&1 ); [ $? -ne 0 ] && ok "drift-check rejects a non-JSON lockfile" || no "invalid JSON must not pass as clean"
rm -rf "$c"

# 7) drift-check warns about a vendored dir NOT in the lockfile, but still passes (panel: coverage gap)
c="$(mkconsumer)"
mkdir -p "$c/.agents/skills/other"; printf -- '---\nname: other\n---\n\n# other\n' > "$c/.agents/skills/other/SKILL.md"
out="$(cd "$c" && bash scripts/drift-check.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && grep -qi "absent from the lockfile" <<<"$out"; } && ok "drift-check warns on an untracked vendored dir, still passes" || no "untracked dir should warn + pass (rc=$rc): $out"
rm -rf "$c"

# 8) first-pin automation: no PLAYBOOK_REF + no lockfile -> resolves local HEAD and pins it
hub3="$(mktemp -d)"; mkdir -p "$hub3/skills/foo"; putscripts "$hub3" "$SRC/sync-agent-skills.sh" "$SRC/build-registry.sh"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hub3/skills/foo/SKILL.md"
( cd "$hub3" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm init )
hub3sha="$(git -C "$hub3" rev-parse HEAD)"
cons3="$(mktemp -d)"; putscripts "$cons3" "$SRC/sync-agent-skills.sh"
sed -i 's/^SKILLS=(.*)$/SKILLS=(foo)/' "$cons3/scripts/sync-agent-skills.sh"
( cd "$cons3" && AGENT_PLAYBOOK_SRC="$hub3" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ); rc=$?
locked_pin="$(jq -r '.pinned_sha' "$cons3/.agents/skills-lock.json" 2>/dev/null)"
{ [ $rc -eq 0 ] && [ "$locked_pin" = "$hub3sha" ]; } && ok "first-pin: no-pin sync resolves & pins local HEAD" || no "first-pin should pin resolved HEAD (rc=$rc pin=$locked_pin want=$hub3sha)"
rm -rf "$hub3" "$cons3"

# 9) first-pin CLONE path (no AGENT_PLAYBOOK_SRC, no pin): clones the hub and pins its DEFAULT
# branch HEAD — exercises the actual new code path (test #8 takes the local-checkout shortcut),
# and confirms it doesn't assume a branch literally named 'main'.
hub4="$(mktemp -d)"; mkdir -p "$hub4/skills/foo"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hub4/skills/foo/SKILL.md"
( cd "$hub4" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -qm init )
hub4sha="$(git -C "$hub4" rev-parse HEAD)"
cons4="$(mktemp -d)"; putscripts "$cons4" "$SRC/sync-agent-skills.sh"
sed -i 's/^SKILLS=(.*)$/SKILLS=(foo)/' "$cons4/scripts/sync-agent-skills.sh"
out="$(cd "$cons4" && AGENT_PLAYBOOK_REPO="$hub4" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
locked_pin="$(jq -r '.pinned_sha' "$cons4/.agents/skills-lock.json" 2>/dev/null)"
{ [ $rc -eq 0 ] && [ "$locked_pin" = "$hub4sha" ]; } && ok "first-pin (clone path): pins the hub default-branch HEAD" || no "clone-path first-pin should pin default HEAD (rc=$rc pin=$locked_pin want=$hub4sha): $out"
rm -rf "$hub4" "$cons4"

# 10) require_tools: a missing hard dep (jq) => exit 3 with an install hint
nobin="$(mktemp -d)"; ln -s "$(command -v bash)" "$nobin/bash"
out="$(PATH="$nobin" bash -c ". '$SRC/lib.sh'; require_tools jq" 2>&1)"; rc=$?
{ [ "$rc" -eq 3 ] && grep -qi "jq" <<<"$out"; } && ok "require_tools: missing jq => exit 3 + install hint" || no "missing jq should exit 3 + hint (rc=$rc): $out"
rm -rf "$nobin"

# 11) jq readers handle MULTIPLE skills + a missing optional field (// "" fallback)
c="$(mktemp -d)"; mkdir -p "$c/.agents/skills/foo" "$c/.agents/skills/bar"; putscripts "$c" "$SRC/drift-check.sh"
printf -- '---\nname: foo\n---\n# foo\n' > "$c/.agents/skills/foo/SKILL.md"
printf -- '---\nname: bar\n---\n# bar\n' > "$c/.agents/skills/bar/SKILL.md"
hfoo="$(dirhash "$c/.agents/skills/foo")"; hbar="$(dirhash "$c/.agents/skills/bar")"
# bar deliberately omits "version" to exercise the // "" fallback in lock_skills
printf '{\n  "playbook_repo": "x",\n  "pinned_sha": "deadbeef",\n  "skills": {\n    "foo": { "version": "1.0.0", "sha256_source": "%s", "sha256_vendored": "%s" },\n    "bar": { "sha256_source": "%s", "sha256_vendored": "%s" }\n  }\n}\n' "$hfoo" "$hfoo" "$hbar" "$hbar" > "$c/.agents/skills-lock.json"
out="$(cd "$c" && bash scripts/drift-check.sh 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && grep -q "2 tracked" <<<"$out"; } && ok "jq readers handle multi-skill + missing optional field" || no "multi-skill drift-check should be clean, 2 tracked (rc=$rc): $out"
rm -rf "$c"

echo "---"
echo "sync-drift: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
