---
name: stuck-on-a-problem
description: Use when you notice you're repeatedly fixing the same class of issue without making real progress — e.g., three or more fix attempts in a row that address symptoms of what looks like the same underlying problem. Signals you're stuck in a local minimum, not that the next fix will be the one that works.
user-invocable: false
version: 1.0.0
---

# Stuck on a problem — step up a level, don't patch again

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
