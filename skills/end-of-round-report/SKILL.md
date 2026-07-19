---
name: end-of-round-report
description: Use when handing back the final summary of a round of work — a shipped fix, a finished review cycle, a research synthesis, a completed multi-step task. Set the conclusion off visibly from the working chatter above it (a horizontal rule + a prominent heading) so the user can scan straight to the outcome, current status, and the one decision they need to make. One such block per round, at the very end. Skip it for trivial conversational replies.
user-invocable: false
version: 1.0.0
---

# End-of-round report

When you finish a round of work and hand it back, the user shouldn't have to read your step-by-step
narration to find out *what happened* and *what's needed next*. Set the conclusion apart and lead with it.

## When to use it
- A round that **produced something**: a shipped change, a finished review cycle, a research synthesis, a
  completed multi-step task, a resolved blocker.
- **Not** for trivial back-and-forth (a one-line answer, a clarifying question) — the ceremony would be noise.
- **One** report block per round, at the **very end** of the message.

## The shape
Keep the step-by-step narration (what you did, tool-by-tool) **above** a horizontal rule. Put the report
**below** it, opening with a prominent heading so it's the visual anchor:

```markdown
...working narration above...

---
# ⎯⎯ Results of last round ⎯⎯

**Outcome —** <the conclusion, in one or two lines, first>
...
```

Use **bullet points**, not dense text.

Below the rule, in this order (drop any section that's empty):
1. **Outcome first.** Lead with the conclusion, not the process — what now exists / works / was decided.
   If there's a verdict (pass/fail, merged/blocked), state it plainly in the first line.
2. **Status & artifacts.** The current state, verification that backs the claim (gates green, tests passing —
   say which), and **links to the artifacts** (PRs, commits, files) so they're clickable, not described.
3. **Next decision / question.** End with the **single** thing you need from the user — the choice to make or
   the approval to give. If there's nothing, say "nothing needed" so the round closes cleanly.

## Principles
- **Distilled, not re-narrated.** The report summarizes; it doesn't repeat the chatter above (see the
  subagent-framework "spec in, distilled result out" rule). If the user wants detail, it's above the rule.
- **Lead with what they must decide.** Bury nothing. If one decision gates the next round, it's the last
  line and it's unmissable.
- **Claims carry evidence.** "Done" means verified — name the gate/test that proves it, or say what's
  unverified and why.
- **Scannable.** Short lines, bold labels, links over prose. A reader skimming only the report should still
  know exactly where things stand.
