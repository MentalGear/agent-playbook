#!/usr/bin/env bash
# One-time local setup for this clone. Idempotent — safe to re-run.
# Registers the git merge driver referenced by .gitattributes so that a merge
# conflict in the generated registry.yaml auto-resolves by regenerating it,
# instead of producing conflict markers in a file no one should hand-edit.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

git config merge.regenerate-registry.name "regenerate registry.yaml on conflict"
# %A is the path git wants the merged result written to. Regenerate, then hand it back.
git config merge.regenerate-registry.driver 'bash scripts/build-registry.sh >/dev/null && cp registry.yaml %A'

echo "✓ regenerate-registry merge driver configured."
echo "  registry.yaml merge conflicts now resolve by regenerating (per .gitattributes)."
