#!/usr/bin/env bash
# Canonical sync script for vendoring agent-playbook skills into a consuming repo.
#
# Copy THIS file into your repo at scripts/sync-agent-skills.sh, set PLAYBOOK_REF
# to a pinned commit SHA, set SKILLS to the skills you want, and run it. It vendors
# `skills/<name>/` from agent-playbook into `.agents/skills/<name>/` (with a
# provenance SHA header injected into each SKILL.md) and (re)creates the
# `.claude/skills/` symlinks the harness discovers.
#
# We vendor (copy + pin a SHA) rather than submodule: it survives ephemeral
# fresh-clone web/sandbox containers, works offline once vendored, and dodges
# submodule-init / egress-proxy friction. Always re-sync with this script rather
# than hand-editing vendored files — they carry a "do not edit here" header and
# hand edits are silently clobbered on the next sync.
#
# Usage:
#   scripts/sync-agent-skills.sh                 # sync at the pinned PLAYBOOK_REF below
#   PLAYBOOK_REF=<sha|tag> scripts/sync-agent-skills.sh
#   AGENT_PLAYBOOK_SRC=/path/to/agent-playbook scripts/sync-agent-skills.sh   # vendor from a local checkout
set -euo pipefail

# --- Pin (bump deliberately; the SHA is what actually pins the content) -----------
# Pin to a specific commit SHA for reproducibility. "main" tracks latest (not pinned).
PLAYBOOK_REF="${PLAYBOOK_REF:-main}"
PLAYBOOK_REPO="${AGENT_PLAYBOOK_REPO:-https://github.com/MentalGear/agent-playbook.git}"
# The skills to vendor (drop any your repo doesn't want):
SKILLS=(subagent-framework agent-operating-principles independent-expert-review)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_dir="$repo_root/.agents/skills"
link_dir="$repo_root/.claude/skills"

# --- Obtain the source tree at the pinned ref ------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [[ -n "${AGENT_PLAYBOOK_SRC:-}" ]]; then
  src="$AGENT_PLAYBOOK_SRC"
  resolved_sha="$(git -C "$src" rev-parse HEAD)"
  # Provenance integrity: the header SHA must reflect what's actually copied.
  if ! git -C "$src" diff --quiet || ! git -C "$src" diff --cached --quiet; then
    echo "WARN: local checkout $src is dirty — header SHA $resolved_sha may not match the copied tree." >&2
  fi
  if [[ "$resolved_sha" != "$PLAYBOOK_REF" && "$(git -C "$src" rev-parse --short HEAD)" != "$PLAYBOOK_REF" ]]; then
    echo "WARN: local checkout is at $resolved_sha but the pinned PLAYBOOK_REF is $PLAYBOOK_REF." >&2
    echo "      Vendoring the local commit; set PLAYBOOK_REF to match, or check out the pin, to keep the pin honest." >&2
  fi
  echo "Vendoring from local checkout $src @ $resolved_sha"
else
  echo "Cloning $PLAYBOOK_REPO @ $PLAYBOOK_REF …"
  git clone --quiet "$PLAYBOOK_REPO" "$work/ap"
  git -C "$work/ap" checkout --quiet "$PLAYBOOK_REF"
  src="$work/ap"
  resolved_sha="$(git -C "$src" rev-parse HEAD)"
fi

mkdir -p "$vendor_dir" "$link_dir"

for skill in "${SKILLS[@]}"; do
  src_skill_dir="$src/skills/$skill"
  [[ -f "$src_skill_dir/SKILL.md" ]] || { echo "ERROR: $skill missing in source ($src_skill_dir/SKILL.md)" >&2; exit 1; }

  dest="$vendor_dir/$skill"
  rm -rf "$dest"
  mkdir -p "$dest"

  # Vendor the WHOLE skill directory (a skill may carry reference.md, assets, etc.),
  # excluding any VCS metadata.
  cp -R "$src_skill_dir/." "$dest/"
  rm -rf "$dest/.git"

  # Record the pinned source SHA as a header comment right after the YAML
  # frontmatter of SKILL.md, so the provenance travels with the entry file.
  awk -v sha="$resolved_sha" -v repo="MentalGear/agent-playbook" '
    BEGIN { fm = 0 }
    NR == 1 && $0 == "---" { print; fm = 1; next }
    fm == 1 && $0 == "---" {
      print
      print ""
      print "<!-- vendored from " repo " @ " sha " — do not edit here; change upstream and re-run scripts/sync-agent-skills.sh -->"
      fm = 2
      next
    }
    { print }
    END { if (fm != 2) { print "ERROR: SKILL.md has no closing frontmatter --- ; provenance header not injected" > "/dev/stderr"; exit 3 } }
  ' "$src_skill_dir/SKILL.md" > "$dest/SKILL.md.tmp"
  mv "$dest/SKILL.md.tmp" "$dest/SKILL.md"   # atomic: only replace on a clean awk run

  # Refresh the harness symlink (relative, matching other vendored skills).
  ln -sfn "../../.agents/skills/$skill" "$link_dir/$skill"
  echo "  ✓ $skill"
done

echo "Synced ${#SKILLS[@]} skill(s) at $resolved_sha"
