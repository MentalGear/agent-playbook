#!/usr/bin/env bash
# Self-test for scripts/decisions.sh: the real records pass, and every planted violation fails.
# A check that has never been seen to fail proves nothing. Run: bash scripts/test/decisions.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
D="$ROOT/scripts/decisions.sh"
pass=0; failed=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
no() { echo "  ✗ $1" >&2; failed=$((failed+1)); }

echo "decisions tests:"

bash "$D" --check >/dev/null 2>&1 && ok "the hub's own records pass" || no "the hub's own records fail the check"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rec() {  # file, decides-block, supersedes
  printf -- '---\n%s\nsupersedes: [%s]\n---\n\n# %s\n\nBody.\n' "$2" "$3" "$1" > "$w/$1"
}
ent() { printf 'decides:\n  - subject: %s\n    outcome: %s\n    statement: %s' "$1" "$2" "${3:-A decision.}"; }

# Fresh fixture: two valid records, the second superseding the first on subject x; then --write.
fixture() {
  rm -rf "$tmp/r"; mkdir -p "$tmp/r/d"; w="$tmp/r/d"
  rec 2026-01-01-a.md "$(ent x adopted)" ""
  rec 2026-01-02-b.md "$(ent x rejected)" "2026-01-01-a.md"
  rec 2026-01-03-f.md "decides: []" ""
  bash "$D" --write --dir "$w" >/dev/null 2>&1
}
expect_fail() {  # label, then a check run after the planting command has run
  if out="$(bash "$D" --check --dir "$w" "${@:2}" 2>&1)"; then no "planted: $1 (check passed)"; else ok "planted: $1"; [ -n "${SHOW:-}" ] && printf "      %s\n" "$(printf "%s" "$out" | grep -v "violation(s)" | head -2)"; fi
}

fixture
bash "$D" --check --dir "$w" >/dev/null 2>&1 && ok "a valid fixture passes after --write" || no "a valid fixture fails"
grep -q 'Superseded on: `x` by' "$w/2026-01-01-a.md" && ok "the superseded record's banner names its successor" \
  || no "the superseded record's banner does not say it is superseded"
grep -q '| `x` | rejected |' "$w/README.md" && ok "the view lists the current holder (a rejection retires a decision)" \
  || no "the view does not list the current holder"

fixture; printf '# no front matter\n' > "$w/2026-01-04-c.md";                       expect_fail "missing front matter"
fixture; rec 2026-01-04-c.md "$(ent y adopted)
decides: []" "";                                                                       expect_fail "duplicate key"
fixture; rec 2026-01-04-c.md "$(ent y approved)" "";                                  expect_fail "outcome outside the vocabulary"
fixture; rec 2026-01-04-c.md "$(ent Y-Bad adopted)" "";                               expect_fail "subject not lower-case-hyphenated"
fixture; rec 2026-01-04-c.md "$(ent y adopted 'Pipes | break tables')" "";            expect_fail "statement with a pipe"
fixture; rec 2026-01-04-c.md "decides:
  - subject: y
    outcome: adopted" "";                                                              expect_fail "entry without a statement"
fixture; rec 2026-01-04-c.md "$(ent y adopted)
extra: field" "";                                                                      expect_fail "a line outside the grammar"
fixture; rec 2026-01-04-c.md "$(ent x adopted)" "";                                   expect_fail "two holders of one subject"
fixture; rec 2026-01-01-a.md "$(ent x adopted)" "2026-01-02-b.md";                    expect_fail "a supersedes cycle"
fixture; rec 2026-01-04-c.md "$(ent x adopted)" "2026-01-09-missing.md, 2026-01-02-b.md"; expect_fail "supersedes a missing record"
fixture; rec 2026-01-04-c.md "$(ent y adopted)" "2026-01-04-c.md";                    expect_fail "supersedes itself"
fixture; rec 2026-01-04-c.md "$(ent y adopted)" "2026-01-02-b.md";                    expect_fail "supersedes a record sharing no subject"
fixture; printf '**Status:** open\n' >> "$w/2026-01-03-f.md";                          expect_fail "a free-text Status line"
fixture; printf -- '---\ndecides: []\nsupersedes: []\n---\n' > "$w/2026-1-5-bad.md";  expect_fail "a file name that is not YYYY-MM-DD-slug.md"
fixture; sed -i 's/| rejected |/| adopted |/' "$w/README.md";                           expect_fail "a hand-edited view"
fixture; sed -i 's/Superseded on/Current on/' "$w/2026-01-01-a.md";                    expect_fail "a hand-edited banner"

# Against a base revision: merged records are frozen except for appended "## Amended" sections.
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
based; rm "$w/2026-01-03-f.md"; bash "$D" --write --dir "$w" >/dev/null 2>&1;   expect_fail "a deleted merged record" --base HEAD
based; sed -i 's/statement: A decision./statement: Another decision./' "$w/2026-01-02-b.md"
bash "$D" --write --dir "$w" >/dev/null 2>&1;                                   expect_fail "changed front matter of a merged record" --base HEAD
based; sed -i 's/^Body\.$/Rewritten body./' "$w/2026-01-03-f.md";                expect_fail "a rewritten body of a merged record" --base HEAD
based; printf '\nAn unmarked addition.\n' >> "$w/2026-01-03-f.md";              expect_fail "an appended section without an Amended heading" --base HEAD

echo "---"
echo "decisions: $pass passed, $failed failed."
[ "$failed" -eq 0 ]
