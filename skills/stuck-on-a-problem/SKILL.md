---
name: stuck-on-a-problem
description: Use when the second instance of the same defect shape shows up. Also when you're repeatedly fixing the same class of issue without progress. Two rules — lift to the class (enumerate every instance, fix them together, land a checked guard) rather than finding a third one at a time, and step up a level of abstraction rather than patching again when fixes cluster around one root cause. Signals you're stuck in a local minimum, not that the next fix will be the one that works.
user-invocable: false
version: 1.1.0
---

# Stuck on a problem — step up a level, don't patch again

## On the second instance, lift to the class

**The second time you see a defect of the same shape, stop fixing instances.** One occurrence is a bug; two
is a *class*, and the class is what you should now be working on. Do three things, in order:

1. **Enumerate** — sweep for every instance (a grep, a probe, a type query — whatever finds the shape, not
   just the two you know about). Expect the count to be higher than two; that's the point of sweeping.
2. **Fix them together**, as one change, so none is left behind to be rediscovered later as a "new" bug.
3. **Land a checked guard** — a test, lint rule, type, or assertion that fails if the shape comes back.
   Without it you've cleared the instances but not closed the class.

**Never find a third instance one at a time.** A class discovered one-by-one keeps costing full
investigation price per instance, and the tail is usually longer than it looks — sweeps routinely turn up
instances that would have taken several more rounds to surface individually.

> The guard is the *floor*, not the goal: before landing one, check whether the class can be eliminated
> outright at a higher rung — see the **solve-by-construction** skill.

## Recognizing the pattern
Review the sequence of problems you've hit and the fixes you've tried. If they cluster around the same root
cause — you keep patching variations of one issue rather than converging on a solution — that's a signal
you're stuck in a local minimum, treating symptoms instead of the disease.

## What to do instead
Stop iterating at the current level. Step back and ask whether there's a higher level of abstraction from
which the entire problem class disappears — a different design, a different boundary, a different
assumption — rather than one more targeted patch.

## Before changing established patterns
If the reframed solution requires deviating from established conventions or architecture in the codebase,
don't do it unilaterally. Explain the pattern you want to break and why, and ask the user for explicit
permission before proceeding.
