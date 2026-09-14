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
#    (own hub — must not mutate the shared $hub that cases 11-13 vendor from)
hub9="$(mkhub)"
( cd "$hub9" && GI checkout -q -b side && printf 'x\n' > skills/foo/extra.md && GI add -A && GI commit -qm side )
sidesha="$(git -C "$hub9" rev-parse side)"; ( cd "$hub9" && GI checkout -q main )
cons="$(mkcons foo)"
out="$(cd "$cons" && PLAYBOOK_REF="$sidesha" AGENT_PLAYBOOK_REPO="$hub9" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi "not an ancestor" <<<"$out"; } && ok "ancestry rejects a fork-only/off-branch pin" || no "ancestry should reject side-branch pin (rc=$rc): $out"
# ...and ALLOW_NONDEFAULT_PIN=1 overrides it
( cd "$cons" && PLAYBOOK_REF="$sidesha" ALLOW_NONDEFAULT_PIN=1 AGENT_PLAYBOOK_REPO="$hub9" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "ALLOW_NONDEFAULT_PIN=1 overrides the ancestry check" || no "override should allow the side pin"
rm -rf "$cons" "$hub9"

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

# 15) rollback guard: a pin bump that isn't a DESCENDANT of the locked pin is rejected
hubr="$(mktemp -d)"; mkdir -p "$hubr/skills/foo"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hubr/skills/foo/SKILL.md"
( cd "$hubr" && git init -q -b main && GI add -A && GI commit -qm c1 )
c1="$(git -C "$hubr" rev-parse HEAD)"
printf 'x\n' > "$hubr/skills/foo/more.md"; ( cd "$hubr" && GI add -A && GI commit -qm c2 )
c2="$(git -C "$hubr" rev-parse HEAD)"
cons="$(mkcons foo)"
( cd "$cons" && PLAYBOOK_REF="$c2" AGENT_PLAYBOOK_REPO="$hubr" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )   # lock at c2
out="$(cd "$cons" && PLAYBOOK_REF="$c1" AGENT_PLAYBOOK_REPO="$hubr" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?   # bump BACK to c1
{ [ $rc -ne 0 ] && grep -qi "not a descendant of the locked pin" <<<"$out"; } && ok "rollback guard rejects a backward pin bump" || no "rollback should reject (rc=$rc): $out"
( cd "$cons" && PLAYBOOK_REF="$c1" ALLOW_ROLLBACK=1 AGENT_PLAYBOOK_REPO="$hubr" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && ok "ALLOW_ROLLBACK=1 overrides the rollback guard" || no "override should allow the backward bump"
rm -rf "$hubr" "$cons"

# 16) REGRESSION GUARD (round-3): ancestry must fire on the RE-SYNC path too, not only on a bump.
#     A lockfile pinned at an off-default-branch commit (as a hand-edit to an unmerged hub SHA would
#     leave it) must be REJECTED on a plain re-sync (no PLAYBOOK_REF), where resolved_sha == locked_sha.
#     Gating the check on "new pin only" silently skipped exactly this case, so a full clone could check
#     out the unmerged commit and — with matching vendored content — pass CI. See the round-3 revert.
hubx="$(mktemp -d)"; mkdir -p "$hubx/skills/foo"
printf -- '---\nname: foo\nversion: 1.0.0\n---\n\n# foo\n' > "$hubx/skills/foo/SKILL.md"
( cd "$hubx" && git init -q -b main && GI add -A && GI commit -qm main1 )
( cd "$hubx" && GI checkout -q -b evil && printf 'x\n' > skills/foo/evil.md && GI add -A && GI commit -qm "unmerged evil" )
evilsha="$(git -C "$hubx" rev-parse evil)"; ( cd "$hubx" && GI checkout -q main )
cons="$(mkcons foo)"
# Simulate a lockfile pinned at the off-branch commit (bypass first-pin ancestry the way a hand-edit would).
( cd "$cons" && PLAYBOOK_REF="$evilsha" ALLOW_NONDEFAULT_PIN=1 AGENT_PLAYBOOK_REPO="$hubx" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
[ "$(jq -r '.pinned_sha' "$cons/.agents/skills-lock.json" 2>/dev/null)" = "$evilsha" ] || no "setup: lockfile should be pinned at the off-branch sha"
# A plain re-sync (no PLAYBOOK_REF, no override) must STILL reject it — here resolved_sha == locked_sha.
out="$(cd "$cons" && AGENT_PLAYBOOK_REPO="$hubx" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi "not an ancestor" <<<"$out"; } \
  && ok "re-sync rejects a lockfile pinned off the default branch (round-3 regression guard)" \
  || no "re-sync must reject an off-branch locked pin even when resolved==locked (rc=$rc): $out"
rm -rf "$cons" "$hubx"

# 17) ASYMMETRY (documented on purpose): the AGENT_PLAYBOOK_SRC local/dev path intentionally TRUSTS the
#     checkout and does NOT run the ancestry check — an off-default-branch HEAD is vendored without
#     rejection. The security boundary is the CLONE path (cases 9 + 16), which CI uses. This test pins the
#     asymmetry so it can't change silently and be mistaken for a bug.
hub17="$(mkhub)"
( cd "$hub17" && GI checkout -q -b side && printf 'x\n' > skills/foo/extra.md && GI add -A && GI commit -qm side )   # leave HEAD off default
cons="$(mkcons foo)"
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hub17" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && ! grep -qi "not an ancestor" <<<"$out"; } \
  && ok "AGENT_PLAYBOOK_SRC path trusts local HEAD (no ancestry check — CI uses the clone path)" \
  || no "SRC path should vendor local HEAD without ancestry (rc=$rc): $out"
rm -rf "$cons" "$hub17"

# 18) rollback guard fail-OPEN (documented): when the locked pin is ABSENT from fetched history (e.g. a hub
#     squash/rewrite dropped it), the guard WARNs and proceeds rather than blocking. An off-branch NEW pin
#     is still caught earlier by the ancestry check, so this fail-open doesn't open a hole — pin the behavior.
hub18="$(mkhub)"; ( cd "$hub18" && printf 'y\n' > skills/foo/more.md && GI add -A && GI commit -qm c2 )
head18="$(git -C "$hub18" rev-parse HEAD)"
cons="$(mkcons foo)"
( cd "$cons" && AGENT_PLAYBOOK_REPO="$hub18" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )   # lock at hub18 HEAD
sed -i 's/"pinned_sha": "[0-9a-f]*"/"pinned_sha": "'"$(printf 'd%039d' 0)"'"/' "$cons/.agents/skills-lock.json"   # foreign locked pin
out="$(cd "$cons" && PLAYBOOK_REF="$head18" AGENT_PLAYBOOK_REPO="$hub18" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && grep -qi "not present in the fetched history" <<<"$out"; } \
  && ok "rollback guard fails open (WARN + proceed) when the locked pin is absent from history" \
  || no "rollback fail-open expected WARN+proceed (rc=$rc): $out"
rm -rf "$cons" "$hub18"

# 19) routing index derives from description's first sentence; a skill without a description contributes nothing
hubh="$(mktemp -d)"; mkdir -p "$hubh/skills/foo" "$hubh/skills/bar"
printf -- '---\nname: foo\nversion: 1.0.0\ndescription: Use when foo happens. Then it does the foo thing at length.\n---\n\n# foo\n' > "$hubh/skills/foo/SKILL.md"
printf -- '---\nname: bar\nversion: 2.0.0\n---\n\n# bar\n' > "$hubh/skills/bar/SKILL.md"
( cd "$hubh" && git init -q -b main && GI add -A && GI commit -qm init )
cons="$(mkcons "foo bar")"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubh" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
{ grep -q '^- \*\*foo happens\*\* → load `foo`$' "$cons/.agents/AGENT_RULES.md" \
    && ! grep -q 'Then it does the foo thing' "$cons/.agents/AGENT_RULES.md" \
    && ! grep -q '`bar`' "$cons/.agents/AGENT_RULES.md"; } \
  && ok "trigger derives from first sentence only; 'Use when' stripped; body excluded" \
  || no "derived routing line wrong: $(grep '^- ' "$cons/.agents/AGENT_RULES.md" || true)"
rm -rf "$cons"

# 20) an over-long first sentence FAILS the sync rather than bloating the index
hubl="$(mktemp -d)"; mkdir -p "$hubl/skills/foo"
LONG="Use when doing something whose opening sentence runs on well past any reasonable routing length and simply will not stop before the cap is hit"
printf -- '---\nname: foo\nversion: 1.0.0\ndescription: %s. Body.\n---\n\n# foo\n' "$LONG" > "$hubl/skills/foo/SKILL.md"
( cd "$hubl" && git init -q -b main && GI add -A && GI commit -qm init )
cons="$(mkcons foo)"
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubl" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi "derived trigger is" <<<"$out"; } \
  && ok "over-long derived trigger fails the sync (budget enforced at generation)" \
  || no "long trigger should fail sync (rc=$rc): $out"
rm -rf "$cons" "$hubl"

# 21) determinism: two ruled skills, declared in reverse order, produce byte-identical output across runs
#     and preserve SKILLS declaration order (the curated reading order).
hubd="$(mktemp -d)"; mkdir -p "$hubd/skills/aaa" "$hubd/skills/zzz"
printf -- '---\nname: aaa\nversion: 1.0.0\ndescription: Use when aaa fires. Body.\n---\n\n# aaa\n' > "$hubd/skills/aaa/SKILL.md"
printf -- '---\nname: zzz\nversion: 1.0.0\ndescription: Use when zzz fires. Body.\n---\n\n# zzz\n' > "$hubd/skills/zzz/SKILL.md"
( cd "$hubd" && git init -q -b main && GI add -A && GI commit -qm init )
cons="$(mkcons "zzz aaa")"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubd" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
h1="$(sha256sum < "$cons/.agents/AGENT_RULES.md")"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubd" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
h2="$(sha256sum < "$cons/.agents/AGENT_RULES.md")"
order="$(grep -o 'load `[a-z]*`' "$cons/.agents/AGENT_RULES.md" | tr '\n' ' ')"
{ [ "$h1" = "$h2" ] && [ "$order" = 'load `zzz` load `aaa` ' ]; } \
  && ok "index is byte-idempotent and follows SKILLS declaration order" \
  || no "determinism/order wrong (identical=$([ "$h1" = "$h2" ] && echo y || echo n) order='$order')"
rm -rf "$cons"

# 22) MIGRATION: a stale GLOBAL_HINTS.md is removed, loudly
cons="$(mkcons "aaa")"
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubd" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
echo "stale" > "$cons/.agents/GLOBAL_HINTS.md"
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubd" bash scripts/sync-agent-skills.sh 2>&1)"
{ [ ! -e "$cons/.agents/GLOBAL_HINTS.md" ] && grep -qi "MIGRATION" <<<"$out"; } \
  && ok "stale GLOBAL_HINTS.md removed with a migration notice" || no "migration removal/notice missing: $out"
rm -rf "$cons" "$hubd" "$hubh"

# 23-27) STANDING RULES: the hub's standing-rules.md becomes the "## Standing rules" section.
hubs="$(mktemp -d)"; mkdir -p "$hubs/skills/aaa"
printf -- '---\nname: aaa\nversion: 1.0.0\ndescription: Use when aaa fires. Body.\n---\n\n# aaa\n' > "$hubs/skills/aaa/SKILL.md"
mkrules() { printf '%s\n' "$@" > "$hubs/standing-rules.md"; ( cd "$hubs" && GI add -A && GI commit -qm r ) >/dev/null 2>&1; }
( cd "$hubs" && git init -q -b main && GI add -A && GI commit -qm init )

# 23) EVERY rule gets its own bullet — not just the first (printf '- %s' over a multi-line string).
cons="$(mkcons "aaa")"
mkrules "# Standing rules" "" "## Rules" "" "- Rule one text." "- Rule two text."
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubs" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
{ grep -qx -- '- Rule one text.' "$cons/.agents/AGENT_RULES.md" \
  && grep -qx -- '- Rule two text.' "$cons/.agents/AGENT_RULES.md" \
  && grep -q '^## Standing rules$' "$cons/.agents/AGENT_RULES.md"; } \
  && ok "every standing rule is emitted as its own bullet" \
  || no "standing rules mis-emitted: $(sed -n '/## Standing rules/,/## Which/p' "$cons/.agents/AGENT_RULES.md")"

# 24) A bullet in the file's own maintainer prose (above `## Rules`) must NOT reach consumers.
mkrules "# Standing rules" "" "- LEAKED example bullet." "" "## Rules" "" "- Rule one text."
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubs" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
{ ! grep -q 'LEAKED' "$cons/.agents/AGENT_RULES.md" && grep -qx -- '- Rule one text.' "$cons/.agents/AGENT_RULES.md"; } \
  && ok "prose bullets above \`## Rules\` are not emitted" || no "prose bullet leaked into AGENT_RULES.md"

# 25) Over the byte cap: fail closed, don't silently bloat every consumer's context.
mkrules "## Rules" "" "- $(head -c 900 < /dev/zero | tr '\0' 'x')"
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubs" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi 'max 800' <<<"$out"; } \
  && ok "over-cap standing rules fail the sync" || no "over-cap not rejected (rc=$rc): $out"

# 26) A rule naming a skill is a ROUTE, not a standing rule — reject it.
mkrules "## Rules" "" '- Always load `subagent-framework` first.'
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubs" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -ne 0 ] && grep -qi 'route, not a rule' <<<"$out"; } \
  && ok "a standing rule naming a skill is rejected" || no "skill-naming rule not rejected (rc=$rc): $out"

# 27) No standing-rules.md at all: routes still render, with no empty Standing-rules section.
rm -f "$hubs/standing-rules.md"; ( cd "$hubs" && GI add -A && GI commit -qm drop ) >/dev/null 2>&1
( cd "$cons" && AGENT_PLAYBOOK_SRC="$hubs" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 )
{ ! grep -q '## Standing rules' "$cons/.agents/AGENT_RULES.md" && grep -q 'load `aaa`' "$cons/.agents/AGENT_RULES.md"; } \
  && ok "no standing-rules.md → routes only, no empty section" || no "empty-standing-rules shape wrong"
rm -rf "$cons" "$hubs"

# 28-31) STALE SCRIPT: a consumer's vendored copy older than the hub must refuse, before mutating.
# Reproduces the real failure: a v1 script against a v2 hub deleted the consumer's rules file, wrote
# no replacement, and exited 0.
hubv="$(mktemp -d)"; mkdir -p "$hubv/skills/aaa" "$hubv/scripts"
printf -- '---\nname: aaa\nversion: 1.0.0\ndescription: Use when aaa fires. Body.\n---\n\n# aaa\n' > "$hubv/skills/aaa/SKILL.md"
cp "$SRC/sync-agent-skills.sh" "$hubv/scripts/"
( cd "$hubv" && git init -q -b main && GI add -A && GI commit -qm init )
cons="$(mkcons "aaa")"

# 28) same version → silent, and the index is written
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubv" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && ! grep -q "stale\|is v[0-9]" <<<"$out" && [ -f "$cons/.agents/AGENT_RULES.md" ]; } \
  && ok "matching script version syncs silently" || no "same-version path noisy or failed (rc=$rc): $out"

# 29) hub NEWER than the consumer's script → refuse, and leave the vendored tree untouched
sed -i 's/^SYNC_SCRIPT_VERSION=[0-9]*$/SYNC_SCRIPT_VERSION=99/' "$hubv/scripts/sync-agent-skills.sh"
( cd "$hubv" && GI add -A && GI commit -qm bump ) >/dev/null 2>&1
# Hash the WHOLE vendored tree + lockfile, not one late-written file: a check that runs after any
# mutation must be caught, not just one that runs after the last mutation.
treehash() { ( cd "$1" && { cat .agents/skills-lock.json 2>/dev/null; \
  find .agents .claude -type f -o -type l 2>/dev/null | LC_ALL=C sort \
  | xargs -I{} sh -c 'echo {}; cat {} 2>/dev/null'; } | sha256sum ); }
pre="$(treehash "$cons")"
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubv" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
post="$(treehash "$cons")"
{ [ $rc -ne 0 ] && grep -q "re-copy\|Re-copy" <<<"$out" && [ "$pre" = "$post" ]; } \
  && ok "stale consumer script refuses and does not touch the vendored tree" \
  || no "stale-script refusal wrong (rc=$rc, tree changed=$([ "$pre" = "$post" ] && echo n || echo y)): $out"

# 30) the override still works, for a deliberate mid-migration run
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubv" ALLOW_STALE_SYNC_SCRIPT=1 bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && grep -q "ALLOW_STALE_SYNC_SCRIPT=1" <<<"$out"; } \
  && ok "ALLOW_STALE_SYNC_SCRIPT=1 overrides the refusal" || no "override failed (rc=$rc): $out"

# 31) hub OLDER than the script is harmless — warn, don't fail
sed -i 's/^SYNC_SCRIPT_VERSION=[0-9]*$/SYNC_SCRIPT_VERSION=1/' "$hubv/scripts/sync-agent-skills.sh"
( cd "$hubv" && GI add -A && GI commit -qm down ) >/dev/null 2>&1
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubv" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && grep -q "pin is behind your script" <<<"$out"; } \
  && ok "hub older than the script warns but succeeds" || no "older-hub path wrong (rc=$rc): $out"
rm -rf "$cons" "$hubv"

# 32-33) TRIGGER COLLISIONS are NOT a sync-time concern — the check belongs to validate-skill, where
# the maintainer who can reword a description sees it. A consumer cannot fix hub wording, so warning
# them on every sync is unactionable noise. Asserted, not merely deleted, so re-adding it is deliberate.
hubc="$(mktemp -d)"; mkdir -p "$hubc/skills/alpha" "$hubc/skills/beta" "$hubc/skills/gamma" "$hubc/scripts"
printf -- '---\nname: alpha\nversion: 1.0.0\ndescription: Use when contributing a skill back to the playbook hub. Body.\n---\n\n# alpha\n' > "$hubc/skills/alpha/SKILL.md"
printf -- '---\nname: beta\nversion: 1.0.0\ndescription: Use when reviewing a skill proposed to the playbook hub. Body.\n---\n\n# beta\n' > "$hubc/skills/beta/SKILL.md"
printf -- '---\nname: gamma\nversion: 1.0.0\ndescription: Use when a subagent crashes mid-flight. Body.\n---\n\n# gamma\n' > "$hubc/skills/gamma/SKILL.md"
cp "$SRC/sync-agent-skills.sh" "$hubc/scripts/"
( cd "$hubc" && git init -q -b main && GI add -A && GI commit -qm init )
cons="$(mkcons "alpha beta gamma")"
out="$(cd "$cons" && AGENT_PLAYBOOK_SRC="$hubc" bash scripts/sync-agent-skills.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && ! grep -qi "near-duplicate" <<<"$out"; } \
  && ok "sync stays silent on colliding triggers (that check is validate-skill's)" \
  || no "sync should not warn on collisions (rc=$rc): $out"
# …and the routes are still generated for every skill, collision or not.
n_routes=$(grep -c '→ load `' "$cons/.agents/AGENT_RULES.md" 2>/dev/null || echo 0)
[ "$n_routes" -eq 3 ] && ok "all routes still emitted when triggers collide" \
  || no "expected 3 routes, got $n_routes"
rm -rf "$cons" "$hubc"

rm -rf "$hub"
echo "---"
echo "sync: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
