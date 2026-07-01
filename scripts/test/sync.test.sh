#!/usr/bin/env bash
# Tests for the deterministic sync model (pivot): sync-agent-skills.sh + lib.sh.
# The integrity gate is "sync is byte-idempotent; CI runs sync then `git status --porcelain`"
# (status, not `git diff --exit-code`, which misses untracked files — see case 13). These tests
# assert determinism, prune, ancestry, first-pin, pin-honesty, tamper-restore, and the gate basis.
# Run: bash scripts/test/sync.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }
putscripts() { local dst="$1"; shift; mkdir -p "$dst/scripts"; cp "$SRC/lib.sh" "$@" "$dst/scripts/"; }

GI() { git -c user.email=t@t -c user.name=t "$@"; }   # git with identity

# A local hub git repo with skills foo+bar, default branch main.
mkhub() {
  local h; h="$(mktemp -d)"; mkdir -p "$h/skills/foo" "$h/skills/bar"
  printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$h/skills/foo/SKILL.md"
  printf -- '---\nname: bar\nversion: 2.0.0\n---\n\n# bar\n' > "$h/skills/bar/SKILL.md"
  ( cd "$h" && git init -q -b main && GI add -A && GI commit -qm init )
  echo "$h"
}
mkcons() { local c; c="$(mktemp -d)"; putscripts "$c" "$SRC/sync-agent-skills.sh"; sed -i "s/^SKILLS=(.*)$/SKILLS=($1)/" "$c/scripts/sync-agent-skills.sh"; echo "$c"; }

echo "sync (deterministic-model) tests:"

# 1) first-pin (local-src): no pin -> pins local HEAD; lockfile has version, NO hashes
hub="$(mkhub)"; pin="$(git -C "$hub" rev-parse HEAD)"; cons="$(mkcons foo)"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ); rc=$?
lp="$(jq -r '.pinned_sha' "$cons/.agents/skills-lock.json" 2>/dev/null)"
fv="$(jq -r '.skills.foo' "$cons/.agents/skills-lock.json" 2>/dev/null)"
hashed="$(grep -c 'sha256' "$cons/.agents/skills-lock.json" 2>/dev/null)"; hashed="${hashed:-0}"
{ [ $rc -eq 0 ] && [ "$lp" = "$pin" ] && [ "$fv" = "1.0.0" ] && [ "$hashed" -eq 0 ]; } \
  && ok "first-pin pins local HEAD; lockfile = {name:version}, no hashes" || no "first-pin lockfile wrong (rc=$rc pin=$lp ver=$fv hashed=$hashed)"

# 2) idempotent: a second sync changes nothing (lockfile + vendored tree byte-identical)
before="$(cd "$cons" && { cat .agents/skills-lock.json; find .agents/skills .claude/skills -type f -o -type l | LC_ALL=C sort | xargs -I{} sh -c 'echo {}; cat {} 2>/dev/null'; } | sha256sum)"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
after="$(cd "$cons" && { cat .agents/skills-lock.json; find .agents/skills .claude/skills -type f -o -type l | LC_ALL=C sort | xargs -I{} sh -c 'echo {}; cat {} 2>/dev/null'; } | sha256sum)"
[ "$before" = "$after" ] && ok "sync is byte-idempotent (the CI git-diff gate)" || no "sync not idempotent"

# 3) provenance header injected + symlink resolves to SKILL.md
grep -q 'vendored from MentalGear/agent-playbook @ '"$pin" "$cons/.agents/skills/foo/SKILL.md" \
  && [ -f "$cons/.claude/skills/foo/SKILL.md" ] && ok "provenance header injected + symlink resolves" || no "header/symlink broken"
rm -rf "$cons"

# 4) prune: dropping a skill from SKILLS removes its vendored dir + symlink
cons="$(mkcons "foo bar")"; ( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
[ -d "$cons/.agents/skills/bar" ] || no "setup: bar should exist after first sync"
sed -i 's/^SKILLS=(.*)$/SKILLS=(foo)/' "$cons/scripts/sync-agent-skills.sh"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
{ [ ! -e "$cons/.agents/skills/bar" ] && [ ! -e "$cons/.claude/skills/bar" ] && [ -d "$cons/.agents/skills/foo" ]; } \
  && ok "prune removes a dropped skill's dir + symlink" || no "prune failed (bar orphan remains)"

# 5) EXTERNAL_SKILLS are exempt from pruning
mkdir -p "$cons/.agents/skills/ext"; printf -- '---\nname: ext\n---\n# ext\n' > "$cons/.agents/skills/ext/SKILL.md"
sed -i 's/^EXTERNAL_SKILLS=(.*)$/EXTERNAL_SKILLS=(ext)/' "$cons/scripts/sync-agent-skills.sh"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
[ -d "$cons/.agents/skills/ext" ] && ok "EXTERNAL_SKILLS exempt from prune" || no "ext should not be pruned"
rm -rf "$cons"

# 6) tamper-restore (the gate's basis): edit a vendored file, re-sync restores it byte-for-byte
cons="$(mkcons foo)"; ( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
good="$(sha256sum "$cons/.agents/skills/foo/SKILL.md")"
echo "MALICIOUS" >> "$cons/.agents/skills/foo/SKILL.md"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
[ "$(sha256sum "$cons/.agents/skills/foo/SKILL.md")" = "$good" ] && ok "re-sync restores a tampered vendored file (git-diff would catch it)" || no "re-sync did not restore tampered file"
rm -rf "$cons"

# 7) pin-honesty: explicit PLAYBOOK_REF != local HEAD hard-errors
cons="$(mkcons foo)"
out="$(cd "$cons" && PLAYBOOK_REF=0000000000000000000000000000000000000000 AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi "disagrees with local checkout" <<<"$out"; } && ok "explicit pin != SRC HEAD hard-errors" || no "pin-honesty failed (rc=$rc)"
rm -rf "$cons"

# 8) first-pin CLONE path + ancestry PASS (pin on default branch)
cons="$(mkcons foo)"
out="$(cd "$cons" && AGENT_PLAYBOOK_REPO="$hub" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
lp="$(jq -r '.pinned_sha' "$cons/.agents/skills-lock.json" 2>/dev/null)"
{ [ $rc -eq 0 ] && [ "$lp" = "$pin" ]; } && ok "clone-path first-pin: ancestry passes, pins default HEAD" || no "clone-path first-pin failed (rc=$rc pin=$lp): $out"
rm -rf "$cons"

# 9) ancestry REJECT: a commit only on a side branch (not an ancestor of default) is refused
( cd "$hub" && GI checkout -q -b side && printf 'x\n' > skills/foo/extra.md && GI add -A && GI commit -qm side )
sidesha="$(git -C "$hub" rev-parse side)"; ( cd "$hub" && GI checkout -q main )
cons="$(mkcons foo)"
out="$(cd "$cons" && PLAYBOOK_REF="$sidesha" AGENT_PLAYBOOK_REPO="$hub" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi "not an ancestor" <<<"$out"; } && ok "ancestry rejects a fork-only/off-branch pin" || no "ancestry should reject side-branch pin (rc=$rc): $out"
# ...and ALLOW_NONDEFAULT_PIN=1 overrides it
( cd "$cons" && PLAYBOOK_REF="$sidesha" ALLOW_NONDEFAULT_PIN=1 AGENT_PLAYBOOK_REPO="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "ALLOW_NONDEFAULT_PIN=1 overrides the ancestry check" || no "override should allow the side pin"
rm -rf "$cons"

# 10) require_tools: missing jq => exit 3 + hint
nobin="$(mktemp -d)"; ln -s "$(command -v bash)" "$nobin/bash"
out="$(PATH="$nobin" bash -c ". '$SRC/lib.sh'; require_tools jq" 2>&1)"; rc=$?
{ [ "$rc" -eq 3 ] && grep -qi "jq" <<<"$out"; } && ok "missing jq => exit 3 + install hint" || no "missing jq should exit 3 (rc=$rc)"
rm -rf "$nobin"

# 11) rogue extra file: an injected non-SKILL.md file in a vendored dir is removed by re-sync
#     (exercises `rm -rf "$dest"`, which tamper-restore on SKILL.md alone does not)
cons="$(mkcons foo)"; ( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
echo "backdoor" > "$cons/.agents/skills/foo/backdoor.md"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
[ ! -e "$cons/.agents/skills/foo/backdoor.md" ] && ok "re-sync removes an injected rogue file (rm -rf \$dest)" || no "rogue file survived re-sync"
rm -rf "$cons"

# 12) the REAL CI gate (git status --porcelain): clean passes, a committed tamper fails
cons="$(mkcons foo)"; ( cd "$cons" && git init -q && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 && GI add -A && GI commit -qm vendor )
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
clean_out="$(cd "$cons" && git status --porcelain -- .agents .claude)"
( cd "$cons" && echo "EVIL" >> .agents/skills/foo/SKILL.md && GI commit -aqm tamper )
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
tamper_out="$(cd "$cons" && git status --porcelain -- .agents .claude)"
{ [ -z "$clean_out" ] && [ -n "$tamper_out" ]; } && ok "git-status gate: clean passes, committed tamper fails" || no "gate wrong (clean='$clean_out' tamper='$tamper_out')"
rm -rf "$cons"

# 13) the gate must use `git status`, not `git diff --exit-code`: the latter MISSES untracked files
cons="$(mkcons foo)"; ( cd "$cons" && git init -q && AGENT_PLAYBOOK_SRC="$hub" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 && GI add -A && GI commit -qm vendor )
echo "untracked" > "$cons/.agents/skills/foo/sneaky.md"
st="$(cd "$cons" && git status --porcelain -- .agents .claude)"
( cd "$cons" && git diff --exit-code -- .agents .claude >/dev/null 2>&1 ); dr=$?
{ [ -n "$st" ] && [ "$dr" -eq 0 ]; } && ok "git status catches an untracked file that git diff --exit-code misses" || no "untracked-file gate justification wrong (status='$st' diff_rc=$dr)"
rm -rf "$cons"

# 14) ancestry FAILS CLOSED when the hub default branch can't be resolved (origin/HEAD dangling)
hubd="$(mktemp -d)"; mkdir -p "$hubd/skills/foo"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hubd/skills/foo/SKILL.md"
( cd "$hubd" && git init -q -b main && GI add -A && GI commit -qm init )
dsha="$(git -C "$hubd" rev-parse HEAD)"
( cd "$hubd" && git symbolic-ref HEAD refs/heads/ghost )   # dangling default → clone can't resolve origin/HEAD
cons="$(mkcons foo)"
out="$(cd "$cons" && PLAYBOOK_REF="$dsha" AGENT_PLAYBOOK_REPO="$hubd" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ "$rc" -eq 2 ] && grep -qi "could not resolve the hub default branch" <<<"$out"; } && ok "ancestry fails closed when origin/HEAD is unresolvable" || no "unresolved default should fail closed (rc=$rc): $out"
( cd "$cons" && PLAYBOOK_REF="$dsha" ALLOW_NONDEFAULT_PIN=1 AGENT_PLAYBOOK_REPO="$hubd" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "ALLOW_NONDEFAULT_PIN=1 bypasses the unresolved-default fail-closed" || no "override should allow when origin/HEAD unresolved"
rm -rf "$cons" "$hubd"

rm -rf "$hub"
echo "---"
echo "sync: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
