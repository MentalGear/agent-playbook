#!/usr/bin/env bash
# Canonical sync script for vendoring agent-playbook skills into a consuming repo.
#
# Copy THIS file into your repo at scripts/sync-agent-skills.sh, set SKILLS to the
# skills you want, and run it. With no pin and no lockfile, the FIRST sync resolves a
# starting commit (default branch 'main', or $PLAYBOOK_DEFAULT_REF) to a concrete 40-char
# SHA and pins THAT — review the resolved SHA in the committed lockfile diff. Or pin
# explicitly the first time:
#     PLAYBOOK_REF=<sha-or-ref> scripts/sync-agent-skills.sh
# After the first sync the pin lives in .agents/skills-lock.json — run with no args to
# re-sync at the locked pin; pass PLAYBOOK_REF=<new-sha> to bump it.
#
# It vendors each whole skill directory into .agents/skills/<name>/ (with a provenance
# header injected into SKILL.md), creates the .claude/skills/ symlinks the harness
# discovers, and writes .agents/skills-lock.json (pin + per-skill version + content
# hashes). The lockfile is read by the drift-check (local edits) and update-check
# (vs the upstream registry). Never hand-edit vendored files — re-run this instead.
set -euo pipefail

PLAYBOOK_REPO="${AGENT_PLAYBOOK_REPO:-https://github.com/MentalGear/agent-playbook.git}"
SKILLS=(subagent-framework agent-operating-principles independent-expert-review project-gates agent-repo-layout agent-access)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor_dir="$repo_root/.agents/skills"
link_dir="$repo_root/.claude/skills"
lockfile="$repo_root/.agents/skills-lock.json"

# --- Resolve the pin: explicit env > lockfile > error ----------------------------
PLAYBOOK_REF_ENV="${PLAYBOOK_REF:-}"   # was it explicitly requested this run?
locked_sha=""
[ -f "$lockfile" ] && locked_sha="$(sed -n 's/.*"pinned_sha"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$lockfile" | head -1)"
PLAYBOOK_REF="${PLAYBOOK_REF:-$locked_sha}"
first_pin=0
if [[ -z "$PLAYBOOK_REF" ]]; then
  # No explicit pin and no lockfile: pin a starting commit (lockfile-on-first-sync — the
  # npm/Cargo/Go/vendir model). The resolved 40-char SHA lands in the committed lockfile, i.e. a
  # reviewable diff; we never store a moving ref as the pin. With no PLAYBOOK_DEFAULT_REF we take
  # the hub's DEFAULT branch (whatever it's named — not an assumed 'main'); set PLAYBOOK_DEFAULT_REF
  # to override.
  first_pin=1
  PLAYBOOK_REF="${PLAYBOOK_DEFAULT_REF:-}"   # empty → the clone path uses the remote's default branch
  echo "NOTE: no pin and no lockfile — resolving a starting commit and pinning it (review the resolved SHA AND playbook_repo in the lockfile diff)." >&2
fi

# --- Obtain the source tree at the pinned ref ------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
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
  # Empty PLAYBOOK_REF (first sync, no explicit ref) → keep the clone's default-branch HEAD,
  # rather than assuming a branch named 'main' (which would hard-fail on a differently-named default).
  if [[ -n "$PLAYBOOK_REF" ]]; then git -C "$work/ap" checkout --quiet "$PLAYBOOK_REF"; fi
  src="$work/ap"
  resolved_sha="$(git -C "$src" rev-parse HEAD)"
fi

# Pin must be a full 40-char commit SHA (a short SHA is ambiguous/collision-wider as a pin).
[[ "$resolved_sha" =~ ^[0-9a-f]{40}$ ]] || { echo "ERROR: resolved pin '$resolved_sha' is not a full 40-char commit SHA." >&2; exit 2; }
if [[ "$first_pin" == 1 ]]; then
  echo "→ First sync: pinned $resolved_sha (from $PLAYBOOK_REPO). REVIEW this SHA AND playbook_repo in $(basename "$lockfile") before committing." >&2
fi

mkdir -p "$vendor_dir" "$link_dir"
lock_entries=()

fm_version() {  # read `version:` from a SKILL.md frontmatter
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$1" | sed -n 's/^version:[[:space:]]*//p' | head -1
}
# Deterministic hash of ALL regular files in a skill dir (path+content) — covers reference.md/assets.
# MUST stay byte-identical to build-registry.sh / validate-skill.sh / drift-check.sh / verify-pin.sh
# (enforced by scripts/test/hash-consistency.test.sh). Requires GNU coreutils (find -print0, sort -z,
# sha256sum) + bash. NB: hashes regular files only (-type f); symlinks are not covered.
skill_dir_hash() {
  ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

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

  ln -sfn "../../.agents/skills/$skill" "$link_dir/$skill"

  ver="$(fm_version "$src_skill_dir/SKILL.md")"; ver="${ver:-0.0.0}"
  sha_source="$(skill_dir_hash "$src_skill_dir")"    # whole-dir hash (covers reference.md/assets)
  sha_vendored="$(skill_dir_hash "$dest")"
  # A command-substitution failure inside the hash (e.g. a vanished file) does NOT trip `set -e`,
  # so guard explicitly. NB: this catches an EMPTY/blank hash; it cannot detect a partial-stream
  # corruption that still yields a 64-hex string — verify-pin (lockfile vs hub@pin) is that backstop.
  for _h in "$sha_source" "$sha_vendored"; do
    [[ "$_h" =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: $skill produced a non-sha256 dir-hash ('$_h') — aborting." >&2; exit 4; }
  done
  lock_entries+=("    \"$skill\": { \"version\": \"$ver\", \"sha256_source\": \"$sha_source\", \"sha256_vendored\": \"$sha_vendored\" }")
  echo "  ✓ $skill ($ver)"
done

# --- Write the lockfile (pin + per-skill versions/hashes) ------------------------
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
} > "$lockfile"

echo "Synced ${#SKILLS[@]} skill(s) at $resolved_sha → $(basename "$lockfile")"
