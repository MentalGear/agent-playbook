---
name: end-of-round-report
description: Use when closing out a round of work. Also when deciding what to commit, push, or park as the round closes. Set the conclusion off visibly from the working chatter above it (a horizontal rule + a prominent heading) so the user can scan straight to the outcome, current status, and the one decision they need to make; push what is committed and green while parking red or in-flight work; and keep harness mechanics (hook nags, tooling prompts) out of the report entirely. One such block per round, at the very end. Skip it for trivial conversational replies.
user-invocable: false
version: 1.1.0
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

**Changes**
- <change one, one line>
- <change two, one line>

**Status**
- <verification one — gate/test name and result>
- <artifact link>

**Next —** <the single decision/question, or "nothing needed">
```

Use **bullet points**, not dense text — every list of changes, statuses, or artifacts below the rule
must render as a `-` list, never as a paragraph packing multiple facts into one block of prose. One
bullet per change/fact; don't merge them with "and"/commas into a run-on line.

Below the rule, in this order (drop any section that's empty):
1. **Outcome first.** Lead with the conclusion, not the process — what now exists / works / was decided.
   If there's a verdict (pass/fail, merged/blocked), state it plainly in the first line.
2. **Changes, as bullets.** Every distinct change (file touched, fix applied, decision made) gets its own
   bullet — one line, one fact. Never fold multiple changes into a single sentence.
3. **Status & artifacts, as bullets.** The current state, verification that backs the claim (gates green,
   tests passing — say which), and **links to the artifacts** (PRs, commits, files) so they're clickable,
   not described — each as its own bullet.
4. **Next decision / question.** End with the **single** thing you need from the user — the choice to make or
   the approval to give. If there's nothing, say "nothing needed" so the round closes cleanly.

## Closing the tree, not just the message

A round also ends in the repository. **Push what is committed and green; park everything else.**

- **Green and committed** → push it. That's the round's artifact, and it's what the report links to.
- **Red, half-finished, or an experiment mid-flight** → **park it**: `git stash` it, or leave it on its own
  branch/worktree. Never commit failing or in-flight work to empty the tree.
- **Never let a tooling prompt drive the commit.** A hook, checker, or CI bot reporting "uncommitted
  changes" is telling you the tree is dirty — *not* that the work is finished. Answer it by pushing what's
  ready and parking what isn't, never by committing red work to silence it.

## Keep harness mechanics out of the report

Hook output, tooling nags, permission prompts, retry noise, and internal plumbing are **not round results**.
Act on them silently and leave them out of the message — the user asked for the work, not a transcript of
the machinery around it. Never quote or paraphrase a hook's complaint back to the user, and never present
one as the reason you did something.

What *does* belong, always: anything that changed the outcome. A gate that failed, work you parked and why,
a step you skipped, a claim you couldn't verify. The rule removes noise, **not** bad news — suppressing a
real failure because it arrived through tooling is the opposite of what this is for.

## Principles
- **Distilled, not re-narrated.** The report summarizes; it doesn't repeat the chatter above (see the
  subagent-framework "spec in, distilled result out" rule). If the user wants detail, it's above the rule.
- **Lead with what they must decide.** Bury nothing. If one decision gates the next round, it's the last
  line and it's unmissable.
- **Claims carry evidence.** "Done" means verified — name the gate/test that proves it, or say what's
  unverified and why.
- **Scannable.** Short lines, bold labels, links over prose. A reader skimming only the report should still
  know exactly where things stand.
