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

echo "---"
echo "validate-skill: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
