#!/usr/bin/env bash
# Dependency-free tests for validate-skill.sh (+ build-registry.sh).
# Each case pins a bug the review panel found. Run: bash scripts/test/validate-skill.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"   # the scripts/ dir under test
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

LONGDESC="A sufficiently long description so the validator's length check is satisfied here."

mkskill() {  # mkskill <hub> <name> <frontmatter-line>...
  local hub="$1" name="$2"; shift 2
  mkdir -p "$hub/skills/$name"
  { echo "---"; for l in "$@"; do echo "$l"; done; echo "---"; echo; echo "# $name"; echo; echo "body"; } \
    > "$hub/skills/$name/SKILL.md"
}
newhub() {  # fresh hub with the scripts + an empty registry built later
  local h; h="$(mktemp -d)"; mkdir -p "$h/scripts"
  cp "$SRC/lib.sh" "$SRC/build-registry.sh" "$SRC/validate-skill.sh" "$h/scripts/"
  echo "$h"
}
# validate <hub> <name> [extra-env] -> RC, OUT
validate() {
  local hub="$1" name="$2" env="${3:-}"
  OUT="$(cd "$hub" && env $env bash scripts/validate-skill.sh "$name" 2>&1)"; RC=$?
}

echo "validate-skill.sh tests:"

# 1) a well-formed read-only skill PASSES (exit 0)
h="$(newhub)"; mkskill "$h" good "name: good" "description: $LONGDESC" "version: 1.0.0" "default-access: read-only"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" good
{ [ "$RC" -eq 0 ] && grep -q "✓ good passed" <<<"$OUT"; } && ok "valid read-only skill passes" || no "valid skill should pass (rc=$RC)"
rm -rf "$h"

# 2) bad semver REJECTS and prints NO ✓ line (panel: misleading ✓ on failure)
h="$(newhub)"; mkskill "$h" bad "name: bad" "description: $LONGDESC" "version: 1.0"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" bad
{ [ "$RC" -ne 0 ] && ! grep -q "✓ bad passed" <<<"$OUT"; } && ok "bad semver rejected, no false ✓" || no "bad semver should reject without ✓ (rc=$RC)"
rm -rf "$h"

# 3) duplicate default-access keys REJECT (panel: parser-differential write smuggling)
h="$(newhub)"; mkskill "$h" dup "name: dup" "description: $LONGDESC" "version: 1.0.0" "default-access: read-only" "default-access: write"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" dup
{ [ "$RC" -ne 0 ] && grep -qi "duplicate frontmatter key" <<<"$OUT"; } && ok "duplicate-key smuggling blocked" || no "duplicate keys should reject (rc=$RC)"
rm -rf "$h"

# 4) the network: modifier is ACCEPTED (panel: validator/vocabulary mismatch)
h="$(newhub)"; mkskill "$h" net "name: net" "description: $LONGDESC" "version: 1.0.0" "default-access: read-only network:off"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" net
[ "$RC" -eq 0 ] && ok "network: modifier accepted" || no "network modifier should pass (rc=$RC): $OUT"
rm -rf "$h"

# 5) write default-access HARD-FAILS by default, PASSES with ALLOW_WRITE_DEFAULT=1 (panel: warn-only too weak)
h="$(newhub)"; mkskill "$h" wr "name: wr" "description: $LONGDESC" "version: 1.0.0" "default-access: write"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" wr
[ "$RC" -ne 0 ] && ok "write default rejected by default" || no "write default should reject (rc=$RC)"
validate "$h" wr "ALLOW_WRITE_DEFAULT=1"
[ "$RC" -eq 0 ] && ok "write default allowed under explicit override" || no "write default should pass with override (rc=$RC): $OUT"
rm -rf "$h"

# 6) the validator does NOT mutate registry.yaml (panel: side-effecting "read-only" check)
h="$(newhub)"; mkskill "$h" a "name: a" "description: $LONGDESC" "version: 1.0.0"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
b0="$(sha256sum "$h/registry.yaml" | cut -d' ' -f1)"
validate "$h" a
b1="$(sha256sum "$h/registry.yaml" | cut -d' ' -f1)"
[ "$b0" = "$b1" ] && ok "validator left registry.yaml unmodified" || no "validator mutated registry.yaml"
# even when stale: edit a skill after building, validator reports stale but still doesn't rewrite
echo "  extra: 1" >> "$h/skills/a/SKILL.md"
validate "$h" a
b2="$(sha256sum "$h/registry.yaml" | cut -d' ' -f1)"
[ "$b1" = "$b2" ] && ok "validator non-mutating even when registry is stale" || no "validator rewrote a stale registry"
rm -rf "$h"

# 7) freshness check FAILS (not silently passes) when build-registry.sh errors (#9 — honor rc)
h="$(newhub)"; mkskill "$h" a "name: a" "description: $LONGDESC" "version: 1.0.0"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
printf '#!/usr/bin/env bash\nexit 1\n' > "$h/scripts/build-registry.sh"   # stub that fails
validate "$h" a
{ [ "$RC" -ne 0 ] && grep -qi "build-registry.sh failed" <<<"$OUT"; } && ok "stale-check fails when build-registry errors" || no "build-registry failure should fail freshness (rc=$RC): $OUT"
rm -rf "$h"

# 8) derived routing trigger: short opener passes; over-long opener REJECTS; superseded mechanisms REJECT
h="$(newhub)"
mkskill "$h" short "name: short" "description: Use when filing a defect. The discipline that keeps evidence honest and so on." "version: 1.0.0"
LONGTRIG="Use when doing something with an opening sentence that runs on well past any reasonable routing length and simply refuses to stop before the cap"
mkskill "$h" longtrig "name: longtrig" "description: $LONGTRIG. Body text here." "version: 1.0.0"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" short
[ "$RC" -eq 0 ] && ok "short first-sentence trigger passes" || no "short trigger should pass (rc=$RC): $OUT"
validate "$h" longtrig
{ [ "$RC" -ne 0 ] && grep -qi "routing trigger" <<<"$OUT"; } && ok "over-long derived trigger REJECTS" || no "long trigger should reject (rc=$RC): $OUT"

# a description not opening "Use when …" still passes but WARNS (derived line would read oddly)
mkskill "$h" noopener "name: noopener" "description: Processes excel files and generates reports for downstream consumers." "version: 1.0.0"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
validate "$h" noopener
{ [ "$RC" -eq 0 ] && grep -qi "should open" <<<"$OUT"; } && ok "non-trigger opener warns but passes" || no "expected warn+pass (rc=$RC): $OUT"

# superseded: the old frontmatter hint, the old when: field, and the old agent-rules.md file all REJECT
mkskill "$h" oldhint "name: oldhint" "description: Use when testing. Body." "version: 1.0.0" "global_agent_file_hint: a stale one-liner"
mkskill "$h" oldwhen "name: oldwhen" "description: Use when testing. Body." "version: 1.0.0" "when: a stale trigger field"
mkskill "$h" oldfile "name: oldfile" "description: Use when testing. Body." "version: 1.0.0"
printf -- '**When x** -> `oldfile`\n' > "$h/skills/oldfile/agent-rules.md"
( cd "$h" && bash scripts/build-registry.sh >/dev/null )
for sk in oldhint oldwhen oldfile; do
  validate "$h" "$sk"
  { [ "$RC" -ne 0 ] && grep -qi "no longer supported" <<<"$OUT"; } && ok "superseded mechanism '$sk' REJECTS with migration message" || no "$sk should reject (rc=$RC): $OUT"
done
rm -rf "$h"

echo "---"
echo "validate-skill: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
