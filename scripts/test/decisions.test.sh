#!/usr/bin/env bash
# Self-test for scripts/decisions.sh: the real records pass, and every planted violation fails with the
# error written for it. Matching the message matters: a planted file also makes the generated view stale,
# so a test that only checked the exit code would pass even with the rule under test deleted.
# Run: bash scripts/test/decisions.test.sh   (SHOW=1 prints each error)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
D="$ROOT/scripts/decisions.sh"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

echo "decisions tests:"

bash "$D" --check >/dev/null 2>&1 && ok "the hub's own records and rule file pass" || no "the hub's own records fail the check"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rec() {  # file, decides-block, supersedes
  printf -- '---\n%s\nsupersedes: [%s]\n---\n\n# %s\n\nBody.\n' "$2" "$3" "$1" > "$w/$1"
}
ent() { printf 'decides:\n  - subject: %s\n    outcome: %s\n    statement: %s' "$1" "$2" "${3:-A decision.}"; }
entr() { printf 'decides:\n  - subject: %s\n    outcome: %s\n    review: %s\n    statement: A decision.' "$1" "$2" "$3"; }

# Fresh fixture: two valid records, the second superseding the first on subject x; then --write.
fixture() {
  rm -rf "$tmp/r"; mkdir -p "$tmp/r/d"; w="$tmp/r/d"
  rec 2026-01-01-a.md "$(ent x adopted)" ""
  rec 2026-01-02-b.md "$(entr x rejected 2026-06-01)" "2026-01-01-a.md"
  rec 2026-01-03-f.md "decides: []" ""
  bash "$D" --write --dir "$w" >/dev/null 2>&1
}
expect_fail() {  # label, regex the error must match, extra args for --check
  local label="$1" re="$2"; shift 2
  if out="$(bash "$D" --check --dir "$w" "$@" 2>&1)"; then no "planted: $label (check passed)"; return; fi
  if printf '%s\n' "$out" | grep -qE "$re"; then
    ok "planted: $label"
    [ -n "${SHOW:-}" ] && printf '      %s\n' "$(printf '%s\n' "$out" | grep -E "$re" | head -1)"
  else
    no "planted: $label (failed, but not with /$re/): $(printf '%s' "$out" | head -1)"
  fi
  return 0
}

fixture
bash "$D" --check --dir "$w" >/dev/null 2>&1 && ok "a valid fixture passes after --write" || no "a valid fixture fails"
grep -q 'Superseded on: `x` by' "$w/2026-01-01-a.md" && ok "the superseded record's banner names its successor" \
  || no "the superseded record's banner does not say it is superseded"
grep -q '| `x` | rejected | A decision. | 2026-06-01 |' "$w/README.md" \
  && ok "the view lists the current holder and its review date (a rejection retires a decision)" \
  || no "the view does not list the current holder and review date"

fixture; printf '# no front matter\n' > "$w/2026-01-04-c.md";         expect_fail "missing front matter" "no front matter"
fixture; rec 2026-01-04-c.md "$(ent y adopted)
decides: []" "";                                                         expect_fail "duplicate key" "duplicate key: decides"
fixture; rec 2026-01-04-c.md "$(ent y approved)" "";                    expect_fail "outcome outside the vocabulary" "outcome must be"
fixture; rec 2026-01-04-c.md "$(ent Y-Bad adopted)" "";                 expect_fail "subject not lower-case-hyphenated" "not lower-case-hyphenated"
fixture; rec 2026-01-04-c.md "$(ent y adopted 'Pipes | break tables')" ""; expect_fail "statement with a pipe" "statement may not contain"
fixture; rec 2026-01-04-c.md "$(entr y adopted 2027-13)" "";            expect_fail "a malformed review date" "review must be a date"
fixture; rec 2026-01-04-c.md "decides:
  - subject: y
    outcome: adopted" "";                                                expect_fail "entry without a statement" "lacks subject, outcome or statement"
fixture; rec 2026-01-04-c.md "$(ent y adopted)
extra: field" "";                                                        expect_fail "a line outside the grammar" "not in the record grammar"
fixture; rec 2026-01-04-c.md "$(ent x adopted)" "";                     expect_fail "two holders of one subject" "subject x is held by"
fixture; rec 2026-01-01-a.md "$(ent x adopted)" "2026-01-02-b.md";      expect_fail "a supersedes cycle" "has no current record"
fixture; rec 2026-01-04-c.md "$(ent x adopted)" "2026-01-09-missing.md, 2026-01-02-b.md"; expect_fail "supersedes a missing record" "which does not exist"
fixture; rec 2026-01-04-c.md "$(ent x adopted)" "../x.md, 2026-01-02-b.md"; expect_fail "supersedes a non-record name" "not a record file name"
fixture; rec 2026-01-04-c.md "$(ent y adopted)" "2026-01-04-c.md";      expect_fail "supersedes itself" "supersedes itself"
fixture; rec 2026-01-04-c.md "$(ent y adopted)" "2026-01-02-b.md";      expect_fail "supersedes a record sharing no subject" "share no subject"
fixture; printf '**Status:** open\n' >> "$w/2026-01-03-f.md";            expect_fail "a free-text Status line" "free-text"
fixture; printf -- '---\ndecides: []\nsupersedes: []\n---\n' > "$w/2026-1-5-bad.md"; expect_fail "a file name that is not YYYY-MM-DD-slug.md" "not a record"
fixture; cp "$w/2026-01-03-f.md" "$w/2026-01-05-g.MD";                   expect_fail "an upper-case .MD file" "not a record"
fixture; mkdir "$w/sub";                                                 expect_fail "a subdirectory" "subdirectory"
fixture; sed -i 's/| rejected |/| adopted |/' "$w/README.md";            expect_fail "a hand-edited view" "README.md is stale"
fixture; sed -i 's/Superseded on/Current on/' "$w/2026-01-01-a.md";     expect_fail "a hand-edited banner" "banner is stale"
fixture; bash "$D" --write --dir "$w" --rule "$tmp/r/rule.md" >/dev/null 2>&1
echo "- an extra instruction" >> "$tmp/r/rule.md";                       expect_fail "a hand-edited rule file" "rule.md is stale" --rule "$tmp/r/rule.md"

# --due: current decisions whose review date has passed.
fixture
TODAY=2026-05-31 bash "$D" --due --dir "$w" >/dev/null 2>&1 && ok "--due passes before the review date" || no "--due fails before the review date"
due_out="$(TODAY=2026-06-01 bash "$D" --due --dir "$w" 2>&1)"; due_rc=$?
if [ "$due_rc" -eq 1 ] && grep -q 'review due since 2026-06-01: x' <<<"$due_out"; then
  ok "--due reports a review on its date"; else no "--due misses a review on its date"; fi

# Against a base revision: merged records are frozen except appended "## Amended" sections and later reviews.
based() {
  fixture
  git -C "$tmp/r" init -q && git -C "$tmp/r" add -A \
    && git -C "$tmp/r" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm base
}
based; bash "$D" --check --dir "$w" --base HEAD >/dev/null 2>&1 && ok "unchanged records pass against the base" \
  || no "unchanged records fail against the base"
based; printf '\n## Amended 2026-02-01\n\nA correction.\n' >> "$w/2026-01-03-f.md"
bash "$D" --check --dir "$w" --base HEAD >/dev/null 2>&1 && ok "an appended Amended section is allowed" \
  || no "an appended Amended section is rejected"
based; sed -i 's/review: 2026-06-01/review: 2026-09-01/' "$w/2026-01-02-b.md"; bash "$D" --write --dir "$w" >/dev/null 2>&1
bash "$D" --check --dir "$w" --base HEAD >/dev/null 2>&1 && ok "moving a review date later is allowed" \
  || no "moving a review date later is rejected"
based; sed -i 's/review: 2026-06-01/review: 2026-03-01/' "$w/2026-01-02-b.md"; bash "$D" --write --dir "$w" >/dev/null 2>&1
expect_fail "moving a review date earlier" "may only move later" --base HEAD
based; sed -i '/review: 2026-06-01/d' "$w/2026-01-02-b.md"; bash "$D" --write --dir "$w" >/dev/null 2>&1
expect_fail "removing a review date" "may only move later" --base HEAD
based; rm "$w/2026-01-03-f.md"; bash "$D" --write --dir "$w" >/dev/null 2>&1
expect_fail "a deleted merged record" "deleted or renamed" --base HEAD
based; sed -i 's/statement: A decision./statement: Another decision./' "$w/2026-01-02-b.md"; bash "$D" --write --dir "$w" >/dev/null 2>&1
expect_fail "changed front matter of a merged record" "front matter of a merged record changed" --base HEAD
based; sed -i 's/^Body\.$/Rewritten body./' "$w/2026-01-03-f.md";       expect_fail "a rewritten body of a merged record" "body of a merged record changed" --base HEAD
based; printf '\nAn unmarked addition.\n' >> "$w/2026-01-03-f.md";     expect_fail "an appended section without an Amended heading" "must start with" --base HEAD

echo "---"
echo "decisions: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
