---
name: verification-instruments
description: Use before recording a defect claim, before trusting a passing test suite, when checking that a fix is actually guarded, and when deciding whether to build a benchmark. The discipline that keeps evidence honest — reproduce a defect against the real system before filing it; formalise the intended semantics as the cheapest oracle; distrust agreement between two forms that share a convention (use foreign vectors); mutation-check the fix rather than the function, in an isolated worktree; and treat benchmarks as committed instruments built when a question hangs on the number. Project-agnostic.
user-invocable: false
version: 1.0.0
global_agent_file_hint: Reproduce a defect against the real system before recording it. Two implementations agreeing proves nothing when they share a convention — use foreign vectors. Mutation-check the fix, not the function, and run hand-applied mutations in an isolated worktree, never the main tree. See verification-instruments.
---

# Verification instruments — keeping the evidence honest

A test that passes, a benchmark that reports a number, and a defect report that sounds right are all
**instruments**. Each can be wrong in a way that looks exactly like being right. This skill is the
discipline that keeps them trustworthy.

## 1. Probe before you file

**Every defect-shaped claim is reproduced against the real system before it is recorded.** Not against your
mental model of the system, not against a simplified harness — the real engine, real path, real data. A
plausible mechanism over-applied files a wrong claim, and a wrong claim in the record costs more than the
defect would have: it sends the next agent hunting something that was never there.

This is the entry condition for a defect report, a backlog item, or a review finding — the same bar the
**independent-expert-review** skill sets for its panel ("a finding you didn't confirm is a *claim*, not a
defect").

## 2. Formalise before trusting tests

**Writing the intended semantics down explicitly is often the cheapest oracle available** — cheaper than
more tests, cheaper than more fuzzing. State what the thing is *supposed* to do (the rules, the invariants,
the edge behaviour) as prose or a small spec, then read the implementation against it.

A written semantics catches a class that test suites structurally cannot: cases nobody thought to test.
Tests encode the behaviours you already imagined; a semantics forces you to enumerate the space. Reach for
it when a subsystem is subtle, when tests keep passing while something still feels wrong, or before you
trust a corpus.

## 3. Agreement proves nothing when the forms share a convention

Two implementations that agree are evidence **only if they were built independently.** If they share an
author, a spec reading, a helper, or an inherited convention, they share the misconception too — and
equivalence testing is structurally blind to it. The same trap applies to a round-trip test (encode then
decode agrees with itself no matter how wrong the encoding is) and to a model-vs-implementation check where
the model was written from the implementation.

**Foreign vectors are the instrument that catches this:** an external corpus, a published test suite, the
reference vectors from a spec, or another project's tests run against your implementation. They're the only
tests that don't share your assumptions. Seek them out for anything with an external contract — a format, a
protocol, an algorithm with a published definition. (This is also the third reuse question the prior-art
survey asks — see **agent-operating-principles** §1.)

## 4. Mutation-check the fix, not the function

A test that passes both before and after your fix is decorative. **Partially revert each distinct form of
the fix and confirm the suite fails loudly** for each one. "The function is covered" is not the claim you
need; the claim is "*this specific change* is guarded."

If a partial revert passes, you've learned something important: the test exercises the code path but not
the behaviour you changed. Fix the test before you trust it.

### Hand-applied mutation checks run in an isolated worktree — never the main tree

A deliberately broken source file sitting in your main working tree is one distraction — or one `git
checkout` of uncommitted work — away from disaster: the mutation gets committed, or real work gets
destroyed reverting it.

```
git worktree add <scratch>/mutcheck HEAD   # isolated copy
# break it, run the suite, confirm it fails
git worktree remove <scratch>/mutcheck
```

**Commit the fix first, regardless** — then nothing being reverted is unsaved, and the worktree is
genuinely disposable. (Scratch locations and their throwaway semantics: see **agent-repo-layout**.)

## 5. Benchmarks are committed instruments

A benchmark is not a one-off script — it's an instrument that has to still be there when someone questions
the number. Keep it **in the repo**, next to what it measures.

- **Capture before/after at the transition**, in the change that makes the transition — then **delete the
  old implementation.** Parallel implementations kept "for comparison" rot: they drift out of sync, stop
  building, and the comparison silently becomes meaningless.
- **Build a benchmark when a question genuinely hangs on the number** — when the decision changes depending
  on the measurement. Otherwise don't: file a **trigger-gated, declared gap** instead ("we have not measured
  X; measure it if Y becomes true"), so the absence is a recorded decision rather than an oversight.

A measurement whose instrument is gone is an assertion, exactly like a claim whose spike was left in
scratch (**agent-operating-principles** §5).

---
*Related: **solve-by-construction** (the fix this verifies), **stuck-on-a-problem** (when the same defect
shape keeps recurring), **independent-expert-review** (verifying findings before accepting them).*
