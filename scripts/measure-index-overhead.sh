#!/usr/bin/env bash
# Is the generated route index earning its always-loaded context?
#
# The routes section duplicates information the harness may already have. Claude Code preloads every
# skill's `name` + full `description` at startup, so for THAT harness the routes are additive, not a
# saving — this script measures by how much. A harness with no such preloading is the opposite case:
# there the index is the only channel, and the descriptions cost nothing because they are never loaded.
#
# Committed as an INSTRUMENT, not a one-off: the ratio moves as skills are added, and a claim nobody
# can re-measure is a claim that quietly goes stale. Run it when the skill set changes materially.
#
# Usage: scripts/measure-index-overhead.sh [path/to/AGENT_RULES.md]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

skills_list="$(grep -oE '^SKILLS=\([^)]*\)' scripts/sync-agent-skills.sh | sed -E 's/^SKILLS=\(|\)$//g')"

desc_bytes=0; n=0
for s in $skills_list; do
  f="skills/$s/SKILL.md"; [ -f "$f" ] || continue
  d="$(awk 'NR==1&&/^---/{fm=1;next} fm&&/^---/{exit} fm' "$f" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  desc_bytes=$((desc_bytes + ${#d} + ${#s})); n=$((n + 1))
done

idx="${1:-}"
if [ -z "$idx" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/scripts"; cp scripts/sync-agent-skills.sh scripts/lib.sh "$tmp/scripts/"
  ( cd "$tmp" && git init -q . && AGENT_PLAYBOOK_SRC="$OLDPWD" bash scripts/sync-agent-skills.sh >/dev/null 2>&1 ) || true
  idx="$tmp/.agents/AGENT_RULES.md"
fi
[ -f "$idx" ] || { echo "ERROR: no AGENT_RULES.md to measure (pass one as \$1)" >&2; exit 1; }

idx_bytes=$(wc -c < "$idx")
standing=$(awk '/^## Standing rules/{f=1;next} /^## /{f=0} f&&/^- /' "$idx" | wc -c)
routes=$((idx_bytes - standing))

printf 'Vendored skills:                         %d\n' "$n"
printf 'Native preload (name + description):     %d bytes\n' "$desc_bytes"
printf 'Generated index total:                   %d bytes\n' "$idx_bytes"
printf '  of which standing rules:               %d bytes\n' "$standing"
printf '  of which routes + scaffolding:         %d bytes\n' "$routes"
echo
echo "In a harness that preloads descriptions (e.g. Claude Code):"
printf '  the routes are ADDITIVE overhead:       +%d%% on always-loaded context\n' "$((idx_bytes * 100 / desc_bytes))"
echo "  the standing rules are NOT — no skill description carries them, so they have no other channel."
echo
echo "In a harness that does NOT preload descriptions:"
printf '  the index is the only channel and costs %d bytes instead of %d.\n' "$idx_bytes" "$desc_bytes"
