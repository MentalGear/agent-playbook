#!/usr/bin/env bash
# Consumer-side PIN verification — makes sha256_source load-bearing.
#
# drift-check proves "vendored == lockfile". This proves "lockfile == hub@pinned_sha": it
# re-fetches agent-playbook at .agents/skills-lock.json's pinned_sha, recomputes each locked
# skill's SOURCE whole-dir hash, and asserts it equals the lockfile's sha256_source (and, when
# the hub ships registry.yaml at that commit, that the registry's published sha256 agrees).
# Without this, sha256_source is recorded but never checked — a dead field giving false assurance.
#
# Network-dependent: skips cleanly (exit 0) when the hub can't be reached, so it belongs in CI,
# not the offline pre-push hook.
#   scripts/verify-pin.sh                                  # clone the hub at the pin
#   AGENT_PLAYBOOK_SRC=/path/to/agent-playbook scripts/verify-pin.sh   # offline: a local checkout AT the pin
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/.agents/skills-lock.json"
[ -f "$lock" ] || { echo "verify-pin: no lockfile ($lock) — run sync-agent-skills.sh first" >&2; exit 2; }

repo="$(sed -n 's/.*"playbook_repo":[[:space:]]*"\([^"]*\)".*/\1/p' "$lock" | head -1)"
pin="$(sed -n 's/.*"pinned_sha"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$lock" | head -1)"
[[ "$pin" =~ ^[0-9a-f]{40}$ ]] || { echo "verify-pin: lockfile pinned_sha '$pin' is not a full 40-char SHA." >&2; exit 2; }

# Anchor trust to the CANONICAL hub, not the lockfile we are auditing. Reading the repo URL from
# the same lockfile would only prove "lockfile matches whatever repo it names" — an attacker who can
# craft the lockfile could point at their own self-consistent tree. Compare against the expected hub
# (override deliberately with VERIFY_PIN_ALLOW_REPO=1, e.g. when verifying a fork).
EXPECTED_REPO="${AGENT_PLAYBOOK_REPO:-https://github.com/MentalGear/agent-playbook.git}"
[ -n "$repo" ] || { echo "verify-pin: lockfile playbook_repo is empty/malformed." >&2; exit 2; }
if [ "$repo" != "$EXPECTED_REPO" ] && [ -z "${VERIFY_PIN_ALLOW_REPO:-}" ]; then
  echo "verify-pin: lockfile playbook_repo '$repo' != expected '$EXPECTED_REPO'." >&2
  echo "            Point AGENT_PLAYBOOK_REPO at the canonical hub, or set VERIFY_PIN_ALLOW_REPO=1 to override." >&2
  exit 2
fi

# Deterministic hash of ALL files in a skill dir (path+content). MUST stay byte-identical
# to sync-agent-skills.sh / build-registry.sh / validate-skill.sh / drift-check.sh.
skill_dir_hash() {
  ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [ -n "${AGENT_PLAYBOOK_SRC:-}" ]; then
  src="$AGENT_PLAYBOOK_SRC"
  have_head="$(git -C "$src" rev-parse HEAD 2>/dev/null || true)"
  [ "$have_head" = "$pin" ] || { echo "verify-pin: local checkout $src is at $have_head, not the pinned $pin — check out the pin or use the network path." >&2; exit 2; }
else
  if ! git clone --quiet "$repo" "$tmp/ap" 2>/dev/null; then
    # Offline by default skips (exit 0) so a dev's network blip doesn't fail the pre-push hook.
    # In CI, set VERIFY_PIN_STRICT=1: a clone failure there means the pin can't be verified —
    # treat that as a failure, not a silent green (else a bad repo URL disables the gate).
    if [ -n "${VERIFY_PIN_STRICT:-}" ]; then
      echo "verify-pin: could not clone $repo and VERIFY_PIN_STRICT is set — failing (pin unverifiable)." >&2; exit 1
    fi
    echo "verify-pin: could not clone $repo (offline?) — skipping."; exit 0
  fi
  git -C "$tmp/ap" checkout --quiet "$pin" 2>/dev/null || { echo "verify-pin: pinned commit $pin not found in $repo." >&2; exit 1; }
  src="$tmp/ap"
fi
reg="$src/registry.yaml"

fails=0; checked=0
# lockfile entries: one line each, carrying "<name>": { ... "sha256_source": "<hash>" ... }
while IFS= read -r line; do
  name="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*"\([A-Za-z0-9_-]*\)":[[:space:]]*{.*/\1/p')"
  [ -z "$name" ] && continue
  want_src="$(printf '%s' "$line" | sed -n 's/.*"sha256_source":[[:space:]]*"\([0-9a-f]*\)".*/\1/p')"
  checked=$((checked+1))   # count PARSED entries, not successes — so a fully-tampered lockfile
                           # reports "does not match" (exit 1), not "malformed lockfile" (exit 2).
  d="$src/skills/$name"
  if [ ! -f "$d/SKILL.md" ]; then echo "  ✗ $name: not present in the hub at $pin" >&2; fails=$((fails+1)); continue; fi
  have_src="$(skill_dir_hash "$d")"
  if [ "$have_src" != "$want_src" ]; then
    echo "  ✗ $name: lockfile sha256_source ($want_src) != hub@$pin source hash ($have_src)" >&2; fails=$((fails+1)); continue
  fi
  # Cross-check the registry published at the pin (Cargo lock-vs-index). A miss is a warning,
  # not a failure: a historical pin may predate registry.yaml.
  if [ -f "$reg" ] && ! grep -qxF "    sha256: $have_src" "$reg"; then
    echo "  ! $name: source hash not found in registry.yaml at the pin (registry may predate this commit)" >&2
  fi
done < <(grep '"sha256_source"' "$lock")

if [ "$checked" -eq 0 ]; then echo "verify-pin: no skills parsed from $lock — malformed lockfile." >&2; exit 2; fi
if [ "$fails" -ne 0 ]; then echo "verify-pin: FAILED — vendored lockfile does not match the hub at $pin ($fails problem(s))." >&2; exit 1; fi
echo "verify-pin: OK — $checked skill(s): lockfile sha256_source matches agent-playbook@$pin."
