#!/usr/bin/env bash
# Receiver-side validator for a skill proposed to this hub (the skill-proposal validation).
# Run before accepting an inbound skill: scripts/validate-skill.sh [<name> | --all]
#
# This is an ADVISORY check for a human, never an auto-accept: a passing run means
# "structurally sound — ready for human review", NOT "merge it". A skill enters the
# hub only with explicit human approval (see the review-skill-proposal skill).
# A `write` default-access hard-fails unless the human sets ALLOW_WRITE_DEFAULT=1.
set -uo pipefail
shopt -s nullglob
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# A base scope, optionally followed by a ` network:on|off` modifier (agent-access vocabulary).
KNOWN_SCOPES_RE='^(read-only|read\+history|propose|write|write:.+)( network:(on|off))?$'
fails=0
warns=0
fail() { echo "  ✗ $1" >&2; fails=$((fails+1)); }
warn() { echo "  ! $1" >&2; warns=$((warns+1)); }

fm_of()    { awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$1"; }
fm_field() { printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }
# scalar field with any YAML inline comment + trailing space stripped (use only for
# short scalar fields — name/version/requires/default-access/isolation — never description)
fm_scalar() { fm_field "$1" "$2" | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'; }
# Deterministic hash of ALL files in a skill dir (path+content). MUST stay byte-identical
# to build-registry.sh / sync-agent-skills.sh / drift-check.sh, or hashes will disagree.
skill_dir_hash() {
  ( cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

validate_one() {
  local name="$1" f="skills/$1/SKILL.md" before="$fails"
  echo "• $name"
  [ -f "$f" ] || { fail "$name: no SKILL.md"; return; }

  local fm; fm="$(fm_of "$f")"
  [ -n "$fm" ] || { fail "$name: no YAML frontmatter"; return; }

  # Reject duplicate frontmatter keys: a real YAML loader takes last-wins, but our
  # scalar reader takes first — a duplicate key could smuggle a different resolved
  # value (e.g. default-access: read-only … default-access: write) past this check.
  local dups; dups="$(printf '%s\n' "$fm" | sed -n 's/^\([A-Za-z0-9_-]*\):.*/\1/p' | sort | uniq -d | tr '\n' ' ')"
  [ -n "${dups// /}" ] && fail "$name: duplicate frontmatter key(s): ${dups}(last-wins ambiguity — not allowed)"

  # name matches directory
  local nm; nm="$(fm_scalar "$fm" name)"
  [ "$nm" = "$name" ] || fail "$name: frontmatter name '$nm' != directory '$name'"

  # description present + non-trivial
  local desc; desc="$(fm_field "$fm" description)"
  [ "${#desc}" -ge 40 ] || fail "$name: description missing or too short (<40 chars)"

  # version present + semver
  local ver; ver="$(fm_scalar "$fm" version)"
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$name: version '$ver' is not semver (x.y.z)"

  # requires must be an inline list [a, b] (block lists aren't parsed → deps would vanish)
  if printf '%s\n' "$fm" | grep -qE '^requires:[[:space:]]*$' && printf '%s\n' "$fm" | grep -qE '^[[:space:]]*-[[:space:]]'; then
    fail "$name: requires must be an inline list (e.g. [a, b]); block-style lists aren't parsed"
  fi
  local req; req="$(fm_scalar "$fm" requires)"
  if [ -n "$req" ]; then
    for dep in $(printf '%s' "$req" | tr -d '[],'); do
      [ -z "$dep" ] && continue
      [ -d "skills/$dep" ] || fail "$name: requires '$dep' which is not a skill in this repo"
    done
  fi

  # access declarations come from the known vocabulary; a write default is high-risk
  local acc; acc="$(fm_scalar "$fm" default-access)"
  if [ -n "$acc" ]; then
    [[ "$acc" =~ $KNOWN_SCOPES_RE ]] || fail "$name: default-access '$acc' is not a known agent-access scope"
    if [[ "$acc" == write* ]]; then
      if [ -n "${ALLOW_WRITE_DEFAULT:-}" ]; then
        warn "$name: default-access is a WRITE scope — allowed via ALLOW_WRITE_DEFAULT; confirm in the human sign-off"
      else
        fail "$name: default-access is a WRITE scope — rejected by default; a maintainer must review and re-run with ALLOW_WRITE_DEFAULT=1 to permit it"
      fi
    fi
  fi
  local iso; iso="$(fm_scalar "$fm" isolation)"
  [ -n "$iso" ] && { [[ "$iso" =~ ^(inline|subagent)$ ]] || fail "$name: isolation '$iso' must be inline|subagent"; }

  # registry carries this skill with a matching whole-dir content hash
  local sha; sha="$(skill_dir_hash "skills/$name")"
  if [ -f registry.yaml ]; then
    grep -q "sha256: $sha" registry.yaml || fail "$name: registry.yaml has no entry with this skill's dir hash — run build-registry.sh"
  else
    fail "registry.yaml missing — run build-registry.sh"
  fi

  [ "$fails" -eq "$before" ] && echo "  ✓ $name passed structural checks"
}

# Registry must be up to date — but this validator must NOT mutate the working tree.
# Regenerate into place, capture, then restore the committed file before reporting.
check_registry_fresh() {
  [ -f scripts/build-registry.sh ] || return 0
  local before after; before="$(mktemp)"; after="$(mktemp)"
  cp registry.yaml "$before" 2>/dev/null || : > "$before"
  bash scripts/build-registry.sh >/dev/null 2>&1
  cp registry.yaml "$after" 2>/dev/null || : > "$after"
  cp "$before" registry.yaml 2>/dev/null || true   # restore — never leave a regenerated file behind
  diff -q "$before" "$after" >/dev/null 2>&1 || fail "registry.yaml is stale — run build-registry.sh and commit it"
  rm -f "$before" "$after"
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
echo "PASSED structural checks: 0 failures, $warns warning(s). NOT accepted — requires human review + approval."
