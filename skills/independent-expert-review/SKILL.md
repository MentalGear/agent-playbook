---
name: independent-expert-review
description: Use when you need a neutral, multi-perspective review of a change, design doc, or artifact — convene a panel of independent expert subagents (one per discipline), each blind to the conclusion you want, collect findings on a fixed severity schema, then synthesize and verify every finding against the code in the main loop. Load before reviewing a non-trivial diff, a new component/API, an architecture decision, or anything you want a second (third, fourth) opinion on. Covers panel sizing, the neutral-reviewer contract, the finding schema, adversarial verification, and why agreement is a severity tiebreaker — not a validity signal.
user-invocable: false
---

# Independent expert review — neutral panels that find real problems

Convene a panel of **independent, neutral** expert subagents to review an artifact, **then verify their
findings yourself**. The leverage is breadth (many disciplines in parallel) and independence (reviewers who
don't share your assumptions). The load-bearing step is the **main loop's synthesis + per-finding
verification** — the panel proposes; you decide.

> **Parameterized skill — resolve these slots from the host repo (its `CLAUDE.md`):**
> - **Verification gates** — the commands the main loop re-runs to confirm a finding is real (type/compile
>   check, tests, etc.). The panel is read-only; verification is where claims get checked.
> - **Persistence location** — where a review round is written up (e.g. a `docs/research/` or `reviews/`
>   folder).
>
> This skill is an orchestration pattern. It stands alone, and it's also the panel pattern referenced by the
> `subagent-framework` skill — use that skill for the broader delegation contract, gates, and logging.

## When to use it (and when not)
- **Use** for: a non-trivial diff, a new component/public API, an architecture or design decision, a
  security/invariant-sensitive surface, or any artifact where one perspective will miss things.
- **Don't** for: a < ~50-line mechanical change, or anything with no writable acceptance check — a single
  disciplined read is cheaper. A panel is not free (see *Cost*).

## 1. Independence & neutrality (the non-negotiable)
The value of a panel collapses if the reviewers are steered. So:
- **Never tell a reviewer the conclusion you want** (or that you wrote the thing, or that "it's probably
  fine"). Ask them to **reach their own verdict on the evidence**.
- **Give every reviewer identical scope** — the same artifact, the same files in/out — so their findings are
  comparable and a disagreement is signal.
- **One discipline per reviewer.** A reviewer told to "check everything" checks nothing deeply. Assign a lens
  (correctness, security, performance, a11y/UX, API design, QA, the relevant language/framework) and let it
  go deep.
- **Read-only.** Reviewers find and cite; they don't edit. The main loop owns every change.

## 2. Size the panel to the surface (don't reflex to five)
- **1–2 reviewers** — a < ~200-line / single-discipline change.
- **2–3 reviewers** — a new component or a cross-discipline surface.
- **Full 5** — a public API / shared primitive / high-stakes architecture decision. Typical lenses:
  language-or-framework · architecture · a11y/UX · performance · QA.

Run the reviewers **in parallel** (one batch, background). Cap concurrency (a handful at a time, ~3–5).

## 3. The reviewer contract (every panelist gets this)
1. **Role/lens** — "world-class expert in X; neutral reviewer on a panel."
2. **Goal** — judge, on the evidence, whether <claim/artifact> is correct/sound. Reach your own verdict.
3. **Scope** — the exact artifact + files in/out (identical across the panel).
4. **Stance** — *don't hedge; prefer false positives to false negatives; **cite file:line or it doesn't
   count**.* Default uncertain findings to "flag it."
5. **Output schema (fixed)** — a verdict + a findings table, each row:
   `**[SEVERITY]** area · file:line · finding · concrete fix`, severity ∈ **BLOCKER / MAJOR / MINOR / NIT**.
   Also: *what was done right* (so synthesis isn't one-sided) and *what you couldn't verify* (and why).
6. **"Your final message IS the deliverable"** — compact, structured; no preamble.

## 4. Synthesize + verify in the main loop (the load-bearing step)
1. **De-dup** findings across reviewers.
2. **Verify each finding against the code** — trace it; reproduce it; reject false positives. This is
   mandatory, not rubber-stamping. A finding you didn't confirm is a *claim*, not a defect.
3. **Re-run the gates** (the host repo's verification commands) for any finding that asserts a broken build /
   failing test.
4. **Adversarial verify** the load-bearing ones — for **BLOCKER/MAJOR** and any security/invariant finding,
   spawn a second neutral agent (identical scope) told to **refute** it; a refutation without a cited
   counter-reason is invalid. Skip for MINOR/NIT (there, "uncertain → keep with a confidence caveat").
5. **Assign final severity and sequence.** **Multi-mention (≥2 disciplines flag the same thing) is a
   severity tiebreaker, NOT a validity signal** — same model family reading the same artifact shares blind
   spots, so agreement can amplify a shared bias. Validity comes from reading the code, not the vote count.

## 5. Cost & persistence
- **Synthesis isn't free.** The de-dup + per-finding verification you must do *after* the panel returns
  costs about as much as reading the artifact yourself once — so a panel doesn't save you the careful read;
  its ~5× spend (N parallel reads on top) buys breadth and independence, not savings. Size to the stakes; a
  panel earns its keep when one perspective would miss things, not by default.
- **Persist** the round (panel, findings, verdicts, what was accepted/rejected and why) in the host repo's
  review/research location, dated. Turn accepted findings into tasks.
