#!/usr/bin/env bash
# Tests for update-check.sh (advisory lockfile-vs-registry check). Uses the offline
# AGENT_PLAYBOOK_SRC path against crafted registry.yaml fixtures. Run:
#   bash scripts/test/update-check.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }
GI() { git -c user.email=t@t -c user.name=t "$@"; }

# mkhub <registry-yaml-content> -> a git repo dir holding registry.yaml
mkhub() { local h; h="$(mktemp -d)"; printf '%s' "$1" > "$h/registry.yaml"; ( cd "$h" && git init -q -b main && GI add -A && GI commit -qm reg ); echo "$h"; }
# mkcons <skills-map-json>  e.g. '"foo": "1.0.0"'  -> a consumer dir with lib.sh + update-check.sh + lockfile
mkcons() { local c; c="$(mktemp -d)"; mkdir -p "$c/scripts" "$c/.agents"; cp "$SRC/lib.sh" "$SRC/update-check.sh" "$c/scripts/";
  printf '{\n  "playbook_repo": "x",\n  "pinned_sha": "%040d",\n  "skills": { %s }\n}\n' 0 "$1" > "$c/.agents/skills-lock.json"; echo "$c"; }
uc() { ( cd "$1" && shift; AGENT_PLAYBOOK_SRC="$HUB" "$@" bash scripts/update-check.sh 2>&1 ); }

echo "update-check tests:"

# 1) up to date: vendored version == registry, nothing new/deprecated
HUB="$(mkhub $'schema: 1\nskills:\n  foo:\n    version: 1.1.0\n    sha256: a\n')"
c="$(mkcons '"foo": "1.1.0"')"
out="$(uc "$c" env)"; { grep -q "up to date" <<<"$out"; } && ok "reports up to date" || no "up-to-date wrong: $out"
rm -rf "$c" "$HUB"

# 2) updated: registry version ahead -> 'updates available' + resolved-SHA adopt line
HUB="$(mkhub $'schema: 1\nskills:\n  foo:\n    version: 1.2.0\n    sha256: a\n')"; hubsha="$(git -C "$HUB" rev-parse HEAD)"
c="$(mkcons '"foo": "1.1.0"')"
out="$(uc "$c" env)"
{ grep -q "updates available" <<<"$out" && grep -q "foo: 1.1.0 → 1.2.0" <<<"$out" && grep -q "PLAYBOOK_REF=$hubsha" <<<"$out"; } \
  && ok "detects an update + prints the resolved adopt SHA" || no "update/adopt wrong: $out"
rm -rf "$c" "$HUB"

# 3) new: registry skill not vendored -> 'new skills'
HUB="$(mkhub $'schema: 1\nskills:\n  foo:\n    version: 1.1.0\n    sha256: a\n  baz:\n    version: 1.0.0\n    sha256: b\n')"
c="$(mkcons '"foo": "1.1.0"')"
out="$(uc "$c" env)"; { grep -q "new skills" <<<"$out" && grep -q "baz (1.0.0)" <<<"$out"; } && ok "detects a new skill" || no "new wrong: $out"
rm -rf "$c" "$HUB"

# 4) VENDORED deprecation: quoted reason unquoted; FAIL_ON_VENDORED_DEPRECATED=1 -> exit 5
HUB="$(mkhub $'schema: 1\nskills:\n  bar:\n    version: 1.0.0\n    sha256: a\n    deprecated: "use baz"\n')"
c="$(mkcons '"bar": "1.0.0"')"
out="$(uc "$c" env)"
{ grep -q "DEPRECATED (vendored here)" <<<"$out" && grep -q "bar → use baz" <<<"$out" && ! grep -q '"use baz"' <<<"$out"; } \
  && ok "vendored deprecation flagged, reason unquoted" || no "vendored-deprecation wrong: $out"
( cd "$c" && AGENT_PLAYBOOK_SRC="$HUB" FAIL_ON_VENDORED_DEPRECATED=1 bash scripts/update-check.sh >/dev/null 2>&1 ); [ $? -eq 5 ] \
  && ok "FAIL_ON_VENDORED_DEPRECATED=1 exits 5 on a vendored deprecation" || no "should exit 5"
rm -rf "$c" "$HUB"

# 5) NON-vendored deprecation does not trip the enforcement exit
HUB="$(mkhub $'schema: 1\nskills:\n  foo:\n    version: 1.0.0\n    sha256: a\n  bar:\n    version: 1.0.0\n    sha256: b\n    deprecated: "gone"\n')"
c="$(mkcons '"foo": "1.0.0"')"
( cd "$c" && AGENT_PLAYBOOK_SRC="$HUB" FAIL_ON_VENDORED_DEPRECATED=1 bash scripts/update-check.sh >/dev/null 2>&1 ); rc=$?
out="$(uc "$c" env)"
{ [ $rc -eq 0 ] && grep -q "deprecated (not vendored)" <<<"$out"; } && ok "non-vendored deprecation is advisory (exit 0)" || no "non-vendored dep wrong (rc=$rc): $out"
rm -rf "$c" "$HUB"

# 6) semver compare via sort -V: 1.2.0 -> 1.10.0 is an update (not a downgrade)
HUB="$(mkhub $'schema: 1\nskills:\n  foo:\n    version: 1.10.0\n    sha256: a\n')"
c="$(mkcons '"foo": "1.2.0"')"
out="$(uc "$c" env)"; grep -q "foo: 1.2.0 → 1.10.0" <<<"$out" && ok "semver: 1.10.0 > 1.2.0 (sort -V)" || no "semver wrong: $out"
rm -rf "$c" "$HUB"

# 7) offline / no-registry source: skip with a message and exit 0 (advisory — a broken/unreachable hub
#    must NOT fail update-check; the weekly workflow surfaces it as a ::warning:: instead). An empty SRC
#    dir has no registry.yaml, exercising the same exit-0-with-message contract as an offline clone.
empty="$(mktemp -d)"
c="$(mkcons '"foo": "1.0.0"')"
out="$(cd "$c" && AGENT_PLAYBOOK_SRC="$empty" bash scripts/update-check.sh 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && grep -qi "no registry.yaml" <<<"$out"; } \
  && ok "no-registry/offline source skips with exit 0 (advisory)" || no "no-registry should exit 0 + message (rc=$rc): $out"
rm -rf "$c" "$empty"

echo "---"
echo "update-check: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
