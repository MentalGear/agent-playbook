#!/usr/bin/env bash
# Consumer-side update check: is my pin behind what agent-playbook now publishes?
# Compares .agents/skills-lock.json against the upstream registry.yaml and reports
# UPDATED skills (registry version ahead of the lock), NEW skills (in the registry,
# not vendored here), and DEPRECATED skills. Advisory only — never fails the build
# (updates are adopted deliberately by bumping the pin and re-running sync).
#   REGISTRY_REF=<branch|sha> scripts/update-check.sh     # default: main
#   AGENT_PLAYBOOK_SRC=/path/to/agent-playbook scripts/update-check.sh   # offline, from a local checkout
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/.agents/skills-lock.json"
[ -f "$lock" ] || { echo "update-check: no lockfile ($lock) — run sync first" >&2; exit 2; }

repo="$(sed -n 's/.*"playbook_repo":[[:space:]]*"\([^"]*\)".*/\1/p' "$lock" | head -1)"
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

# locked versions:  name<TAB>version   (parsed from the JSON lock entries)
lock_versions="$(grep '"sha256_vendored"' "$lock" \
  | sed -n 's/^[[:space:]]*"\([A-Za-z0-9_-]*\)":.*"version":[[:space:]]*"\([^"]*\)".*/\1\t\2/p')"
# registry versions + deprecations:  name<TAB>version<TAB>deprecated?
reg_data="$(awk '
  /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { name=$1; sub(/:$/,"",name); ver[name]=""; dep[name]="" ; order[++n]=name; next }
  /^    version:/ { v=$2; ver[name]=v; next }
  /^    deprecated:/ { sub(/^[[:space:]]*deprecated:[[:space:]]*/,""); dep[name]=$0; next }
  END { for (i=1;i<=n;i++){k=order[i]; printf "%s\t%s\t%s\n", k, ver[k], dep[k]} }
' "$reg")"

lv() { printf '%s\n' "$lock_versions" | awk -F'\t' -v k="$1" '$1==k{print $2}'; }
newer() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ] && [ "$1" != "$2" ]; }

updated=(); new=(); deprecated=()
while IFS=$'\t' read -r name rver rdep; do
  [ -z "$name" ] && continue
  [ -n "$rdep" ] && deprecated+=("$name → $rdep")
  locked="$(lv "$name")"
  if [ -z "$locked" ]; then new+=("$name ($rver)")
  elif [ "$locked" != "$rver" ] && newer "$locked" "$rver"; then updated+=("$name: $locked → $rver"); fi
done <<< "$reg_data"

echo "update-check vs ${repo##*/}@${REGISTRY_REF}:"
if [ "${#updated[@]}" -eq 0 ] && [ "${#new[@]}" -eq 0 ] && [ "${#deprecated[@]}" -eq 0 ]; then
  echo "  ✓ up to date"; exit 0
fi
[ "${#updated[@]}" -gt 0 ]    && { echo "  ▲ updates available:"; printf '      - %s\n' "${updated[@]}"; }
[ "${#new[@]}" -gt 0 ]        && { echo "  + new skills:";        printf '      - %s\n' "${new[@]}"; }
[ "${#deprecated[@]}" -gt 0 ] && { echo "  ⚠ deprecated:";        printf '      - %s\n' "${deprecated[@]}"; }
if [[ "$resolved_ref_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "  To adopt ${REGISTRY_REF} (resolved → $resolved_ref_sha):"
  echo "      PLAYBOOK_REF=$resolved_ref_sha scripts/sync-agent-skills.sh   # then add any NEW skills to SKILLS"
else
  echo "  To adopt: PLAYBOOK_REF=<new-sha> scripts/sync-agent-skills.sh (and add any new skills to SKILLS)."
fi
