#!/usr/bin/env bash
# Consumer-side update check: is my pin behind what agent-playbook now publishes?
# Compares .agents/skills-lock.json against the upstream registry.yaml and reports
# UPDATED skills (registry version ahead of the lock), NEW skills (in the registry,
# not vendored here), and DEPRECATED skills. Advisory only — never fails the build
# (updates are adopted deliberately by bumping the pin and re-running sync).
#   REGISTRY_REF=<branch|tag> scripts/update-check.sh     # default: main (NOT a commit SHA — the
#                                                         # shallow --branch clone needs a branch/tag)
#   AGENT_PLAYBOOK_SRC=/path/to/agent-playbook scripts/update-check.sh   # offline, from a local checkout
#   FAIL_ON_VENDORED_DEPRECATED=1 scripts/update-check.sh   # exit 5 if a VENDORED skill is deprecated (CI)
set -uo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" || { echo "update-check: cannot source lib.sh" >&2; exit 3; }
require_tools git jq
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/.agents/skills-lock.json"
[ -f "$lock" ] || { echo "update-check: no lockfile ($lock) — run sync first" >&2; exit 2; }
jq -e . "$lock" >/dev/null 2>&1 || { echo "update-check: $lock is not valid JSON." >&2; exit 2; }

repo="$(lock_repo "$lock")"
REGISTRY_REF="${REGISTRY_REF:-main}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
reg="$tmp/registry.yaml"

# Also resolve REGISTRY_REF to the concrete commit SHA behind it, so we can print an exact,
# copy-pasteable pin to adopt (the registry itself can't carry the commit that contains it).
resolved_ref_sha=""
if [ -n "${AGENT_PLAYBOOK_SRC:-}" ]; then
  cp "$AGENT_PLAYBOOK_SRC/registry.yaml" "$reg" 2>/dev/null || { echo "update-check: no registry.yaml in $AGENT_PLAYBOOK_SRC" >&2; exit 0; }
  resolved_ref_sha="$(git -C "$AGENT_PLAYBOOK_SRC" rev-parse HEAD 2>/dev/null || true)"
else
  if ! git clone --quiet --depth 1 --branch "$REGISTRY_REF" "$repo" "$tmp/ap" 2>/dev/null; then
    echo "update-check: could not fetch $repo@$REGISTRY_REF (offline?) — skipping."; exit 0
  fi
  cp "$tmp/ap/registry.yaml" "$reg" 2>/dev/null || { echo "update-check: upstream has no registry.yaml — skipping."; exit 0; }
  resolved_ref_sha="$(git -C "$tmp/ap" rev-parse HEAD 2>/dev/null || true)"
fi

# locked skills, US-separated rows: name<US>version (see lib.sh lock_skills).
lock_versions="$(lock_skills "$lock")"
# registry versions + deprecations:  name<TAB>version<TAB>deprecated?
reg_data="$(awk '
  /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { name=$1; sub(/:$/,"",name); ver[name]=""; dep[name]="" ; order[++n]=name; next }
  /^    version:/ { v=$2; ver[name]=v; next }
  /^    deprecated:/ { sub(/^[[:space:]]*deprecated:[[:space:]]*/,""); gsub(/^"|"$/,""); dep[name]=$0; next }
  END { for (i=1;i<=n;i++){k=order[i]; printf "%s\t%s\t%s\n", k, ver[k], dep[k]} }
' "$reg")"

lv() { printf '%s\n' "$lock_versions" | while IFS=$'\x1f' read -r n v; do [ "$n" = "$1" ] && { printf '%s' "$v"; return; }; done; }
newer() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ] && [ "$1" != "$2" ]; }

updated=(); new=(); deprecated=(); vdep=()   # vdep = deprecations of skills VENDORED here
while IFS=$'\t' read -r name rver rdep; do
  [ -z "$name" ] && continue
  locked="$(lv "$name")"
  if [ -n "$rdep" ]; then
    if [ -n "$locked" ]; then vdep+=("$name → $rdep"); else deprecated+=("$name → $rdep"); fi
  fi
  if [ -z "$locked" ]; then new+=("$name ($rver)")
  elif [ "$locked" != "$rver" ] && newer "$locked" "$rver"; then updated+=("$name: $locked → $rver"); fi
done <<< "$reg_data"

echo "update-check vs ${repo##*/}@${REGISTRY_REF}:"
if [ "${#updated[@]}" -eq 0 ] && [ "${#new[@]}" -eq 0 ] && [ "${#deprecated[@]}" -eq 0 ] && [ "${#vdep[@]}" -eq 0 ]; then
  echo "  ✓ up to date"; exit 0
fi
[ "${#updated[@]}" -gt 0 ]    && { echo "  ▲ updates available:";        printf '      - %s\n' "${updated[@]}"; }
[ "${#new[@]}" -gt 0 ]        && { echo "  + new skills:";               printf '      - %s\n' "${new[@]}"; }
[ "${#vdep[@]}" -gt 0 ]       && { echo "  ⛔ DEPRECATED (vendored here):"; printf '      - %s\n' "${vdep[@]}"; }
[ "${#deprecated[@]}" -gt 0 ] && { echo "  ⚠ deprecated (not vendored):"; printf '      - %s\n' "${deprecated[@]}"; }
if [ "${#updated[@]}" -gt 0 ] || [ "${#new[@]}" -gt 0 ]; then
  if [[ "$resolved_ref_sha" =~ ^[0-9a-f]{40}$ ]]; then
    echo "  To adopt ${REGISTRY_REF} (resolved → $resolved_ref_sha):"
    echo "      PLAYBOOK_REF=$resolved_ref_sha scripts/sync-agent-skills.sh   # then add any NEW skills to SKILLS"
  else
    echo "  To adopt: PLAYBOOK_REF=<new-sha> scripts/sync-agent-skills.sh (and add any new skills to SKILLS)."
  fi
  if [ "${#new[@]}" -gt 0 ]; then
    echo "      ⚠ NEW skills stay UNVENDORED until you add their names to the SKILLS=(…) array in"
    echo "        scripts/sync-agent-skills.sh — re-syncing without that edit silently leaves them out"
    echo "        (the integrity gate sees nothing changed, so it won't warn you)."
  fi
fi

# Enforcement hook: with FAIL_ON_VENDORED_DEPRECATED=1, exit non-zero when a skill you VENDOR is
# deprecated upstream — lets CI surface it as a warning/failure (advisory exit 0 otherwise).
if [ "${#vdep[@]}" -gt 0 ] && [ -n "${FAIL_ON_VENDORED_DEPRECATED:-}" ]; then
  echo "update-check: ${#vdep[@]} vendored skill(s) deprecated upstream (FAIL_ON_VENDORED_DEPRECATED set)." >&2
  exit 5
fi

exit 0   # explicit: reaching here means the check ran cleanly (advisory — never fails the build)
