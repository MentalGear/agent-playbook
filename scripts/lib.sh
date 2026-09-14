#!/usr/bin/env bash
# Shared helpers for the agent-playbook vendoring toolchain — the SINGLE source of truth.
# Source it (`. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"`); never copy these functions inline.
# Hard deps: bash, GNU coreutils, and jq (for lockfile reads). skill_dir_hash is used by the hub's
# build-registry/validate-skill (the published registry's content hash); the consumer's integrity
# gate is sync + `git status --porcelain` (not `git diff`, which ignores untracked files), not a hash.

# Fail loudly if a required tool is absent (better than silently mis-parsing / wrong hashes).
require_tools() {
  local t missing=()
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: missing required tool(s): ${missing[*]}" >&2
    case " ${missing[*]} " in
      *" jq "*) echo "  jq is required for lockfile parsing — install it (apt: jq · brew: jq · https://jqlang.github.io/jq/)" >&2 ;;
    esac
    exit 3
  fi
}

# Deterministic hash of ALL regular files in a skill dir (path+content) — used by build-registry.sh
# / validate-skill.sh for the registry's published sha256. Go's `h1:` dirhash shape; NUL-delimited
# so a filename with a newline can't corrupt the file list. Hashes regular files only (-type f).
skill_dir_hash() {
  ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' p; do
      printf '%s\0' "$p"; sha256sum "$p" | cut -d' ' -f1; done | sha256sum | cut -d' ' -f1 )
}

# --- Routing-trigger collision detection --------------------------------------------------------
# Two triggers that read alike are the dominant misrouting cause: the agent picks whichever it saw
# first and the other skill never loads. Reads "name<TAB>trigger" lines on stdin; writes
# "score<TAB>nameA<TAB>nameB" for each pair at or above THRESHOLD, worst first.
#
# The measure is LEXICAL, not semantic: Jaccard overlap of content words (stopwords dropped). It
# catches the realistic authoring failure — a trigger written by copying a neighbour's and tweaking
# it — and will NOT catch two triggers that mean the same thing in different words. Claiming
# otherwise would be the interesting lie here, so: it is a duplicate-wording check.
#
# THRESHOLD=0.30 is measured, not guessed: across this hub's 13 skills the only pair at or above it
# is propose-skill/review-skill-proposal at 0.333, and the next-highest real pair sits at 0.091 — a
# 3.6x margin, so the cut is nowhere near a knife-edge.
trigger_collisions() {
  local threshold="${1:-0.30}"
  awk -F'\t' -v thr="$threshold" '
    function norm(s,  i,w,n,arr,out) {
      s=tolower(s); gsub(/[^a-z0-9 ]/," ",s); n=split(s,arr," "); out=""
      for(i=1;i<=n;i++){ w=arr[i]
        if(w ~ /^(a|an|the|or|and|to|of|is|it|its|in|on|at|for|with|that|this|you|your|what|where|when|before|about|out|up|back|else|elsewhere)$/) continue
        if(length(w)<2) continue
        out=out" "w }
      return out }
    NF>=2 { name[++n]=$1; trig[n]=norm($2) }
    END{
      for(i=1;i<=n;i++) for(j=i+1;j<=n;j++){
        split(trig[i],A," "); split(trig[j],B," ")
        delete SA; delete SB
        for(k in A) SA[A[k]]=1
        for(k in B) SB[B[k]]=1
        inter=0; uni=0
        for(w in SA){ uni++; if(w in SB) inter++ }
        for(w in SB) if(!(w in SA)) uni++
        if(uni>0 && inter/uni >= thr) printf "%.3f\t%s\t%s\n", inter/uni, name[i], name[j]
      }
    }' | LC_ALL=C sort -rn
}

# --- Lockfile (.agents/skills-lock.json) readers — jq, not sed/grep ----------------------------
# `// ""` coalesces a missing field to empty ON PURPOSE: an empty pin fails the 40-char-SHA regex in
# sync, so the downstream checks are the real gate. Don't "simplify" those checks away.
lock_pin()  { jq -r '.pinned_sha   // ""' "$1"; }   # the pinned commit SHA
lock_repo() { jq -r '.playbook_repo // ""' "$1"; }   # the hub repo URL
# One row per skill: name<US>version, joined by US (0x1f, ASCII unit separator). Read with
# `IFS=$'\x1f' read -r name ver`. US is deliberately NOT a tab (tab is IFS-whitespace, which would
# collapse an empty field and shift columns); US is non-whitespace, so empty fields are preserved.
# `(.skills // {})` so a lockfile missing the skills key yields zero rows instead of a raw jq error.
# Lockfile skills values are version strings — no content hashes (sync + git diff is the gate).
lock_skills() {
  jq -r '(.skills // {}) | to_entries[] | [ .key, (.value // "") ] | join("\u001f")' "$1"
}
