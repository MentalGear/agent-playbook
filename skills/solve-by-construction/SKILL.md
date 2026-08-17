---
name: solve-by-construction
description: Use when choosing between designs, or about to land a guard, check, or assert. Also when deciding where a fix belongs. Runs the loop deconstruct → construct → check against prior art. Prefer designs that make a failure mode structurally impossible over designs that defend against it at runtime — climb the ladder (guard at the site → validate at a boundary → route through an existing checkpoint → make it unrepresentable) instead of patching where the defect surfaced; run the deconstruction exercise to test whether the current form is the truest one; apply the elegance test to tell real elimination from a guard in disguise; re-run the whole check on the plan before building; and sweep existing code once an invariant lands. Project-agnostic.
user-invocable: false
version: 1.0.0
---

# Solve by construction — eliminate the failure mode, don't defend against it

When choosing between two designs, prefer the one that makes a failure mode **structurally impossible**
over the one that adds a check for it after the fact — encode an invariant in a type/schema rather than a
runtime assert, remove a race by construction (single writer, clear ownership) rather than add a lock
around it, make an illegal state unrepresentable rather than validate against it. This is a planning-phase
bias: reach for elimination before defense, and reserve runtime checks for boundaries where elimination
genuinely isn't possible (real external input, a third-party API).

## 0. The loop — deconstruct, construct, then check against prior art

Three beats, in order. Most of this skill is beat 2; the beats on either side are what keep it honest.

1. **Deconstruct to the root** (§2) — find the layer the problem actually lives at, not the one it
   surfaced at.
2. **Construct the fix there** (§1, §3) — climb the ladder to the highest rung the elegance test allows.
3. **Check the construction against prior art** — before committing to it, look up how this problem is
   already solved (**agent-operating-principles** §1). Ask the three reuse questions of what you find:
   can we integrate it, lift the approach, or reuse its tests against ours?

**Beat 3 is the one that gets skipped**, because a construction you just derived feels finished — and
because the better it feels, the less inclined you are to go looking. That instinct is backwards: an
elegant-feeling construction is *more* likely to be a solved problem under a name you don't know yet, or
a known anti-pattern the ecosystem already rejected for a reason you haven't hit. The survey is cheap
next to discovering either one after you've built on it.

When beat 3 contradicts beat 2, the prior art wins by default — it carries evidence your derivation
doesn't. Overriding it is allowed, but then say what the prior art got wrong and why your case differs;
record that as a negative (§1 of **agent-operating-principles**) so the next pass doesn't re-litigate it.

## 1. Climb the ladder before you land a guard

**Never land a guard at the defect site without first checking the rungs above it.** The grades rank the
fix you actually land — 1 is best:

- **Rung 0 — guard at the site** (grade 3): a check after the fact, where the defect surfaced.
- **Rung 1 — validate at a boundary** (grade 2): check once at a type/parse boundary, so downstream sites
  can't reintroduce it.
- **Rung 2 — route through an existing checkpoint** (grade 2): the value already passes a boundary that
  could own this constraint — route through it and add **no new check at all**.
- **Rung 3 — make it unrepresentable** (grade 1): a substrate or representation choice removes the defect
  class entirely.

**Not every constraint has a rung 3.** When the constraint's own definition is itself mutable or replicated
state (a bound that is itself synced data, a limit the environment can change under you), a **gate plus a
detector** is the top of the ladder — there's nothing to make unrepresentable. Take the highest rung whose
cost the elegance test (§3) allows, and **file the higher rungs as explicit, gated termini** rather than
discarding them: "rung 3 requires switching encodings, gated on X" is a recorded decision; silence is a
forgotten one.

> **Worked example — all four rungs on one defect.** A signature verifier accepts an all-zero public key,
> which validates any message.
> - *Rung 0:* guard each verify call against the zero key — every call site must remember.
> - *Rung 1:* validate keys at parse, so a bad key can't get past the edge.
> - *Rung 2:* mint a validated-key type at the trust-on-first-use boundary **every key already passes** —
>   raw keys never reach verify, and no new check was added.
> - *Rung 3:* adopt an encoding in which such keys **cannot be represented at all**.

## 2. The deconstruction exercise — is this the truest form?

Don't settle for the first layer where the problem is visible, and don't assume the shape you reached for
is the essential one. **Deconstruct one level of abstraction up** — toward the more general condition the
symptom is an instance of, or the more basic form the approach is a special case of — and ask whether it's
better solved (or better expressed) there instead. Repeat until moving up stops simplifying things.

Run it deliberately, as an exercise, on two things:
- **The fix** — where does this defect *belong*, as opposed to where it surfaced? (That's §1's ladder.)
- **The form itself** — is this really the most essential, truest approach, or an incidental one that
  happens to work? A design that survives being deconstructed upward twice is usually near its real shape.

The layer where the construction can't be pushed further without losing what makes it a construction is
where the fix belongs — not necessarily where the symptom first appeared.

## 3. The elegance test — tell real elimination from a guard in disguise

A genuine by-construction fix **removes more complexity than it adds while preserving the same desirable
properties.** If a "construction" fix nets *more* code, more state, or a new invariant to maintain, it
isn't elimination — it's a guard wearing construction's clothing, and it deserves the same scrutiny as any
other defensive check.

## 4. Re-run the check on the plan, not just the code

After writing an implementation plan, **review it against §1–§3 before building.** If the review improves
the plan and the improved plan still holds, run the check again — **iterate to a fixpoint.** This is the
plan-time twin of §5: the cheapest place to delete a construction is before it exists. In practice this is
where duplicated per-adapter validators collapse into one shared validator, and where a planned guard turns
out to have a rung-2 checkpoint already sitting in the design.

## 5. Landing an invariant means sweeping for it

When a change eliminates a failure mode by construction, **check whether the same failure mode exists
elsewhere** in the codebase and would benefit from the same fix. A construction-based fix that isn't
retroactively swept is only half-landed — the old guard-based instances stay in place, still needing
defense, still able to drift from the new invariant. The method audits its own output: every landed
invariant triggers the sweep.

---
*Related: **stuck-on-a-problem** (when repeated same-class fixes signal you're below the right rung),
**verification-instruments** (proving the fix actually holds), and **agent-operating-principles** §1
(surveying prior art before committing to a design).*
