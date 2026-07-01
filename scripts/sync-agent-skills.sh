#!/usr/bin/env bash
# Canonical sync script for vendoring agent-playbook skills into a consuming repo.
#
# INTEGRITY MODEL — sync is DETERMINISTIC. Re-running it at the pinned SHA reproduces the vendored
# tree + lockfile byte-for-byte. So the integrity gate is simply: in CI, run this script and then
# `git status --porcelain -- .agents .claude` (NOT `git diff --exit-code`, which ignores untracked
# files — an orphaned skill dir left by a rename would slip past it). Any hand-edit to a vendored
# skill, a doctored lockfile, an orphaned skill dir, or an injected symlink shows up as drift and
# fails the build. There are NO
# content hashes and no separate drift-check/verify-pin scripts — git IS the content check, and
# re-deriving from the hub at the pin is what ties the vendored bytes back to upstream.
#
# Copy THIS file + lib.sh into your repo's scripts/, set SKILLS (and EXTERNAL_SKILLS for any skills
# vendored from a different upstream), and run it:
#   - First sync (no pin): resolves the hub's default branch to a concrete 40-char SHA, verifies the
#     SHA is an ANCESTOR of that branch (rejects a fork-only/off-branch pin), and pins it. Review the
#     resolved SHA + playbook_repo in the committed lockfile diff.
#   - Bump:  PLAYBOOK_REF=<sha-or-ref> scripts/sync-agent-skills.sh
#   - Re-sync at the locked pin: run with no args.
# Overrides: PLAYBOOK_DEFAULT_REF (first-pin ref), ALLOW_NONDEFAULT_PIN=1 (skip ancestry check).
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh" || { echo "sync: cannot source lib.sh" >&2; exit 3; }
require_tools git jq

PLAYBOOK_REPO="${AGENT_PLAYBOOK_REPO:-https://github.com/MentalGear/agent-playbook.git}"
SKILLS=(subagent-framework agent-operating-principles independent-expert-review project-gates agent-repo-layout agent-access)
# Skills vendored under .agents/skills/ from a DIFFERENT upstream — not synced here and exempt from
# pruning. IMPORTANT: external skills are OUTSIDE this gate's integrity perimeter — re-sync never
# touches them, so a malicious edit to their CONTENT is NOT caught by the `git status` CI gate (only
# the symlink-hygiene check applies to them). Verify external skills via their own upstream + PR
# review, or content-pin them separately. (Empty in the canonical template.)
EXTERNAL_SKILLS=()

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_dir="$repo_root/.agents/skills"
link_dir="$repo_root/.claude/skills"
lockfile="$repo_root/.agents/skills-lock.json"

# --- Resolve the pin: explicit env > lockfile > first-pin default --------------------------------
PLAYBOOK_REF_ENV="${PLAYBOOK_REF:-}"   # was it explicitly requested this run?
locked_sha=""
[ -f "$lockfile" ] && locked_sha="$(lock_pin "$lockfile")"
PLAYBOOK_REF="${PLAYBOOK_REF:-$locked_sha}"
first_pin=0
if [[ -z "$PLAYBOOK_REF" ]]; then
  # No explicit pin and no lockfile: pin a starting commit (lockfile-on-first-sync). With no
  # PLAYBOOK_DEFAULT_REF we take the hub's DEFAULT branch (whatever it's named), then ancestry-check it.
  first_pin=1
  PLAYBOOK_REF="${PLAYBOOK_DEFAULT_REF:-}"   # empty → the clone path uses the remote's default branch
  echo "NOTE: no pin and no lockfile — resolving a starting commit and pinning it (review the resolved SHA AND playbook_repo in the lockfile diff)." >&2
fi

# --- Obtain the source tree at the pinned ref ----------------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work" "$lockfile.tmp"' EXIT
if [[ -n "${AGENT_PLAYBOOK_SRC:-}" ]]; then
  src="$AGENT_PLAYBOOK_SRC"
  resolved_sha="$(git -C "$src" rev-parse HEAD)"
  if ! git -C "$src" diff --quiet || ! git -C "$src" diff --cached --quiet; then
    echo "WARN: local checkout $src is dirty — header SHA $resolved_sha may not match the copied tree." >&2
  fi
  if [[ -n "$PLAYBOOK_REF_ENV" && "$resolved_sha" != "$PLAYBOOK_REF_ENV" && "$(git -C "$src" rev-parse --short HEAD 2>/dev/null)" != "$PLAYBOOK_REF_ENV" ]]; then
    echo "ERROR: explicit PLAYBOOK_REF=$PLAYBOOK_REF_ENV disagrees with local checkout HEAD $resolved_sha." >&2
    echo "       Check out that ref in $src, or omit PLAYBOOK_REF to vendor (and pin) local HEAD." >&2
    exit 2
  fi
  echo "Vendoring from local checkout $src @ $resolved_sha"
else
  if [[ -n "$PLAYBOOK_REF" ]]; then
    echo "Cloning $PLAYBOOK_REPO @ $PLAYBOOK_REF …"
  else
    echo "Cloning $PLAYBOOK_REPO (default branch) …"
  fi
  git clone --quiet "$PLAYBOOK_REPO" "$work/ap"
  # Empty PLAYBOOK_REF (first sync, no explicit ref) → keep the clone's default-branch HEAD.
  if [[ -n "$PLAYBOOK_REF" ]]; then git -C "$work/ap" checkout --quiet "$PLAYBOOK_REF"; fi
  src="$work/ap"
  resolved_sha="$(git -C "$src" rev-parse HEAD)"
  # Ancestry check: the pin must be reachable from the hub's DEFAULT branch — rejects a SHA that
  # only exists on a fork or an unmerged branch (the "pinned a bad SHA from a malicious fork" class).
  if [[ -z "${ALLOW_NONDEFAULT_PIN:-}" ]]; then
    def_ref="$(git -C "$src" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [[ -n "$def_ref" ]]; then
      git -C "$src" merge-base --is-ancestor "$resolved_sha" "$def_ref" 2>/dev/null || {
        echo "ERROR: pin $resolved_sha is not an ancestor of the hub default branch (${def_ref##*/})." >&2
        echo "       Refusing a fork-only/off-branch pin. Set ALLOW_NONDEFAULT_PIN=1 to override." >&2
        exit 2; }
    else
      # Fail closed: if we can't resolve the default branch we can't run the ancestry check, so
      # don't silently accept the pin. Bypass deliberately with ALLOW_NONDEFAULT_PIN=1.
      echo "ERROR: could not resolve the hub default branch for the ancestry check." >&2
      echo "       Set ALLOW_NONDEFAULT_PIN=1 to bypass (only if you trust this pin)." >&2
      exit 2
    fi
  fi
fi

# Pin must be a full 40-char commit SHA (a short SHA is ambiguous/collision-wider as a pin).
[[ "$resolved_sha" =~ ^[0-9a-f]{40}$ ]] || { echo "ERROR: resolved pin '$resolved_sha' is not a full 40-char commit SHA." >&2; exit 2; }

# Rollback guard: on a pin BUMP, the new pin must be a DESCENDANT of the currently-locked pin (old is
# an ancestor of new) — catches an accidental backward/divergent bump. Skipped on first pin, an
# unchanged pin, or when the old pin isn't in the fetched history. Override with ALLOW_ROLLBACK=1.
if [[ -n "$locked_sha" && "$resolved_sha" != "$locked_sha" && -z "${ALLOW_ROLLBACK:-}" ]]; then
  if git -C "$src" cat-file -e "${locked_sha}^{commit}" 2>/dev/null; then
    git -C "$src" merge-base --is-ancestor "$locked_sha" "$resolved_sha" 2>/dev/null || {
      echo "ERROR: new pin $resolved_sha is not a descendant of the locked pin $locked_sha (rollback/divergent bump)." >&2
      echo "       Set ALLOW_ROLLBACK=1 to override." >&2
      exit 2; }
  else
    echo "WARN: locked pin $locked_sha not present in the fetched history — skipping the rollback check." >&2
  fi
fi

if [[ "$first_pin" == 1 ]]; then
  echo "→ First sync: pinned $resolved_sha (from $PLAYBOOK_REPO). REVIEW this SHA AND playbook_repo in $(basename "$lockfile") before committing." >&2
fi

mkdir -p "$vendor_dir" "$link_dir"
lock_entries=()

fm_version() {  # read `version:` from a SKILL.md frontmatter
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$1" | sed -n 's/^version:[[:space:]]*//p' | head -1
}

# Pre-validate every SKILL exists at the source BEFORE mutating the vendor tree, so a typo in
# SKILLS can't leave a half-applied tree (some skills re-copied, the rest stale).
for skill in "${SKILLS[@]}"; do
  [[ -f "$src/skills/$skill/SKILL.md" ]] || { echo "ERROR: $skill missing in source ($src/skills/$skill/SKILL.md)" >&2; exit 1; }
done

for skill in "${SKILLS[@]}"; do
  src_skill_dir="$src/skills/$skill"
  [[ -f "$src_skill_dir/SKILL.md" ]] || { echo "ERROR: $skill missing in source ($src_skill_dir/SKILL.md)" >&2; exit 1; }

  dest="$vendor_dir/$skill"
  rm -rf "$dest"; mkdir -p "$dest"
  cp -R "$src_skill_dir/." "$dest/"
  rm -rf "$dest/.git"

  awk -v sha="$resolved_sha" -v repo="MentalGear/agent-playbook" '
    BEGIN { fm = 0 }
    NR == 1 && $0 == "---" { print; fm = 1; next }
    fm == 1 && $0 == "---" {
      print; print ""
      print "<!-- vendored from " repo " @ " sha " — do not edit here; change upstream and re-run scripts/sync-agent-skills.sh -->"
      fm = 2; next
    }
    { print }
    END { if (fm != 2) { print "ERROR: SKILL.md has no closing frontmatter --- ; provenance header not injected" > "/dev/stderr"; exit 3 } }
  ' "$src_skill_dir/SKILL.md" > "$dest/SKILL.md.tmp"
  mv "$dest/SKILL.md.tmp" "$dest/SKILL.md"

  # Replace the symlink target cleanly: rm first so a pre-existing real dir isn't nested into.
  rm -rf "$link_dir/$skill"
  ln -sfn "../../.agents/skills/$skill" "$link_dir/$skill"

  ver="$(fm_version "$src_skill_dir/SKILL.md")"; ver="${ver:-0.0.0}"
  lock_entries+=("    \"$skill\": \"$ver\"")
  echo "  ✓ $skill ($ver)"
done

# --- Prune vendored skills no longer in SKILLS (and not externally managed) -----------------------
keep=" ${SKILLS[*]} ${EXTERNAL_SKILLS[*]:-} "
if [ -d "$vendor_dir" ]; then
  for d in "$vendor_dir"/*/; do
    [ -d "$d" ] || continue; n="$(basename "$d")"
    case "$keep" in *" $n "*) : ;; *) echo "  – pruning removed skill: $n" >&2; rm -rf "$d" "$link_dir/$n" ;; esac
  done
fi
if [ -d "$link_dir" ]; then
  for l in "$link_dir"/*; do
    { [ -e "$l" ] || [ -L "$l" ]; } || continue; n="$(basename "$l")"
    case "$keep" in *" $n "*) : ;; *) rm -rf "$l" ;; esac   # rm -rf: also clears a real-dir orphan
  done
fi

# Sort skill entries so the lockfile is deterministic regardless of the SKILLS array order.
if [ "${#lock_entries[@]}" -gt 0 ]; then
  mapfile -t lock_entries < <(printf '%s\n' "${lock_entries[@]}" | LC_ALL=C sort)
fi

# --- Write the lockfile atomically (pin + per-skill version; NO hashes — git is the content check) -
{
  echo "{"
  echo "  \"playbook_repo\": \"$PLAYBOOK_REPO\","
  echo "  \"pinned_sha\": \"$resolved_sha\","
  echo "  \"skills\": {"
  for i in "${!lock_entries[@]}"; do
    sep=","; [ "$i" -eq $((${#lock_entries[@]} - 1)) ] && sep=""
    echo "${lock_entries[$i]}$sep"
  done
  echo "  }"
  echo "}"
} > "$lockfile.tmp"
mv -f "$lockfile.tmp" "$lockfile"

echo "Synced ${#SKILLS[@]} skill(s) at $resolved_sha → $(basename "$lockfile")"
