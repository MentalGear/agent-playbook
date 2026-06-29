#!/usr/bin/env bash
# Receiver-side validator for a skill proposed to this hub (the skill-proposal validation).
# Run before accepting an inbound skill: scripts/validate-skill.sh [<name> | --all]
# Exits non-zero with reasons if any check fails. See the review-skill-proposal skill.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

KNOWN_SCOPES_RE='^(read-only|read\+history|propose|write|write:.+)$'
fails=0
warns=0
fail() { echo "  ✗ $1" >&2; fails=$((fails+1)); }
warn() { echo "  ! $1" >&2; warns=$((warns+1)); }

fm_of()    { awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$1"; }
fm_field() { printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }
# scalar field with any YAML inline comment + trailing space stripped
fm_scalar() { fm_field "$1" "$2" | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'; }

validate_one() {
  local name="$1" dir="skills/$1" f="skills/$1/SKILL.md"
  echo "• $name"
  [ -f "$f" ] || { fail "$name: no SKILL.md"; return; }

  local fm; fm="$(fm_of "$f")"
  [ -n "$fm" ] || { fail "$name: no YAML frontmatter"; return; }

  # name matches directory
  local nm; nm="$(fm_scalar "$fm" name)"
  [ "$nm" = "$name" ] || fail "$name: frontmatter name '$nm' != directory '$name'"

  # description present + non-trivial
  local desc; desc="$(fm_field "$fm" description)"
  [ "${#desc}" -ge 40 ] || fail "$name: description missing or too short (<40 chars)"

  # version present + semver
  local ver; ver="$(fm_scalar "$fm" version)"
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$name: version '$ver' is not semver (x.y.z)"

  # requires resolve to real skills
  local req; req="$(fm_scalar "$fm" requires)"
  if [ -n "$req" ]; then
    for dep in $(printf '%s' "$req" | tr -d '[],'); do
      [ -z "$dep" ] && continue
      [ -d "skills/$dep" ] || fail "$name: requires '$dep' which is not a skill in this repo"
    done
  fi

  # access declarations are from the known vocabulary; a write default needs maintainer sign-off
  local acc; acc="$(fm_scalar "$fm" default-access)"
  if [ -n "$acc" ]; then
    [[ "$acc" =~ $KNOWN_SCOPES_RE ]] || fail "$name: default-access '$acc' is not a known agent-access scope"
    [[ "$acc" == write* ]] && warn "$name: default-access is a WRITE scope — requires explicit maintainer approval"
  fi
  local iso; iso="$(fm_scalar "$fm" isolation)"
  if [ -n "$iso" ]; then
    [[ "$iso" =~ ^(inline|subagent)$ ]] || fail "$name: isolation '$iso' must be inline|subagent"
  fi

  # registry carries this skill with a matching content hash
  local sha; sha="$(sha256sum "$f" | cut -d' ' -f1)"
  if [ -f registry.yaml ]; then
    grep -q "sha256: $sha" registry.yaml || fail "$name: registry.yaml has no entry with this SKILL.md's sha256 — run build-registry.sh"
  else
    fail "registry.yaml missing — run build-registry.sh"
  fi
  echo "  ✓ $name passed structural checks"
}

# registry must be up to date with the working tree
check_registry_fresh() {
  local tmp; tmp="$(mktemp)"
  cp registry.yaml "$tmp" 2>/dev/null || true
  bash scripts/build-registry.sh >/dev/null
  if ! diff -q "$tmp" registry.yaml >/dev/null 2>&1; then
    fail "registry.yaml was stale (regenerated). Commit the updated registry.yaml."
  fi
  rm -f "$tmp"
}

targets=()
if [ "${1:---all}" = "--all" ]; then
  for d in skills/*/; do targets+=("$(basename "$d")"); done
else
  targets=("$1")
fi

echo "Validating ${#targets[@]} skill(s)…"
check_registry_fresh
for t in "${targets[@]}"; do validate_one "$t"; done

echo "---"
if [ "$fails" -gt 0 ]; then
  echo "REJECTED: $fails failure(s), $warns warning(s)." >&2; exit 1
fi
echo "ACCEPTED: 0 failures, $warns warning(s)."
