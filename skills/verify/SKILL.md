---
name: verify
description: Use after making a code change, before reporting it done — drive the running app to the changed surface and observe. Not tests (that's CI), not type-checking (that's build): run the real app, hit the real path, capture what you see. Covers finding the changed surface, getting a handle on the app, driving it to the changed path, probing edge cases, capturing evidence, and writing a PASS/FAIL/BLOCKED/SKIP verdict. Load before any "confirm this works" task on a GUI, CLI, server, or library.
user-invocable: true
version: 1.0.0
---

# Verify — runtime observation of a code change

**Verification is runtime observation.** Build the app, run it, drive it to where the changed code executes,
and capture what you see. That capture is the evidence. Nothing else is.

**Don't run tests. Don't typecheck.** Running them here proves you can run CI — not that the change works.
Not as a warm-up, not "just to be sure," not as a regression sweep after. The time goes to running the
app instead.

**Don't import-and-call.** `import { foo } from './src/...'` then `console.log(foo(x))` is a unit test you
wrote. The function did what the function does — you knew that from reading it. The app never ran. Whatever
calls `foo` in the real codebase ends at a CLI, a socket, or a window. Go there.

---

## 1. Find the change

The scope is what you're verifying — usually a diff, sometimes just "does X work." In a git repo, establish
the full range (a branch may be many commits, or the change may still be uncommitted):

```bash
git log --oneline @{u}..              # count commits (if upstream set)
git diff @{u}.. --stat                # full range, not HEAD~1
git diff origin/HEAD... --stat        # no upstream: committed vs base
git diff HEAD --stat                  # uncommitted: working tree vs HEAD
```

State the commit count. Large diff truncating? Redirect to a file then read it. Repo but no diff from any
of these → say so, stop. **No repo → the scope is whatever the user named; ask if they didn't.**

**The diff is ground truth. Any description is a claim about it.** Read both. If they disagree, that's a
finding.

---

## 2. Identify the surface

The surface is where a user — human or programmatic — meets the change. That's where you observe.

| Change reaches | Surface | You |
|---|---|---|
| CLI / TUI | terminal | type the command, capture the pane |
| Server / API | socket | send the request, capture the response |
| GUI | pixels | drive it under xvfb/Playwright, screenshot |
| Library | package boundary | sample code through the public export (`import pkg`, not `import ./src/...`) |
| Prompt / agent config | the agent | run the agent, capture its behavior |
| CI workflow | Actions | dispatch it, read the run |

**Internal function? Not a surface.** Something in the repo calls it and that caller ends at one of the rows
above. Follow it there.

**No runtime surface at all** — docs-only, type declarations with no emit, build config that produces no
behavioral diff — report **SKIP — no runtime surface: (reason).** Don't run tests to fill the space.

**Tests in the diff are the author's evidence, not a surface.** CI runs them. Tests-only PR → SKIP, one
line. Mixed src+tests → verify the src, ignore the test files. Reading a test to learn what to check is
fine — it's a spec. But then go run the app.

---

## 3. Get a handle

**Check `.claude/skills/` first — even if you already know how to build and run.** A matching `verifier-*`
skill is the repo's evidence-capture protocol: it wraps the session so a reviewer can replay what you saw.

```bash
ls .claude/skills/
```

- **`verifier-*` matching your surface** → invoke it with the Skill tool and follow its setup. Mismatched
  surface → skip that one, try the next. Stale verifier (fails on mechanics unrelated to the change) → ask
  the user whether to patch it; don't FAIL the change for verifier rot.
- **`run-*` but no matching verifier** → use its build/launch primitives as your handle.
- **Neither** → cold start from README/package.json/Makefile. Timebox ~15 min. Stuck → BLOCKED with exactly
  where you stopped.

---

## 4. Drive it

Smallest path that makes the changed code execute:

- Changed a flag? Run with it.
- Changed a handler? Hit that route.
- Changed error handling? Trigger the error.
- Changed an internal function? Find the CLI command / request / render that reaches it. Run that.

**Read your plan back before running.** If every step is build / typecheck / run test file — you've planned
a CI rerun, not a verification. Find a step that reaches the surface or report BLOCKED.

**The verdict is table stakes. Your observations are the signal.** A PASS with three sharp "I noticed…"
lines is worth more than a bare PASS. You're the only reviewer who actually *ran* the thing — anything that
made you pause, work around, or go "huh" is information the author doesn't have.

**End-to-end, through the real interface.** Pieces passing in isolation doesn't mean the flow works — seams
are where bugs hide. If users click buttons, test by clicking buttons, not by curling the API underneath.

**Destructive path?** If the change touches code that deletes, publishes, sends, or writes outside the
workspace and there's no dry-run or safe target, don't drive it live. Verify what you can around it and say
which path you didn't exercise and why.

---

## 5. Probe it

The claim checked out — that's the first half. Confirming is step one, not the job. The description is what
the author intended; your value is what they didn't.

You know exactly what changed. Probe *around* it, at the same surface you just drove:

- **New flag / option** → empty value, passed twice, combined with a conflicting flag, typo'd
- **New handler / route** → wrong method, malformed body, missing required field, oversized payload
- **Changed error path** → the adjacent errors it didn't touch — did the refactor catch them too, or only
  the one in the diff?
- **Interactive / GUI** → keyboard shortcuts, rapid-fire the action, Esc at wrong moment, garbage input
- **State / persistence** → do it twice, do it with stale state underneath, do it in two sessions at once
- **Wander** → what's adjacent? What looked off while you were confirming? Go back to it.

These aren't a checklist — pick the ones the change points at. Stop when you've covered the obvious
adjacents or hit something worth flagging.

Mark every probe with 🔍 in the Steps list, even when it passes — "🔍 empty `--from` → clean error, exit 2"
tells the author what *was* covered, which they can't see from a bare PASS.

---

## 6. Capture evidence

Stdout, response bodies, screenshots, pane dumps. Captured output is evidence; memory isn't. Something
unexpected? Don't route around it — capture, note, decide if it's the change or the environment.

**Evidence has to reach the reader.** A file path is only evidence if the reader can open it. If
`SendUserFile` (or equivalent) is available, send the screenshots and recordings and reference them in the
report. Without it, keep the evidence inline — pane captures and response bodies travel in the report; a
bare path only works when the reader shares your filesystem.

Shared process state (ports, lockfiles) — isolate. `mktemp -d`, bind `:0`, unique ports. You share a
namespace with your host.

---

## 7. Report

Write the report inline in your final message:

```
## Verification: <one-line what changed>

**Verdict:** PASS | FAIL | BLOCKED | SKIP

**Claim:** <what it's supposed to do — your read of the diff and/or stated claim; note any mismatch>

**Method:** <how you got a handle — which verifier/run-skill, or cold start; what you launched>

### Steps

Each step is one thing you did to the **running app** and what it showed.
Build / install / checkout are setup, not steps. Test runs and typecheck don't belong here.

1. ✅/❌/⚠️/🔍 <what you did to the running app> → <what you observed>
   <evidence: the app's own output — screenshot, pane capture, response body>

🔍 marks a probe. At least one 🔍 required — a Steps list that's all ✅ is a happy-path replay.

**Screenshot / sample:** <the one frame a reviewer looks at to see the feature>

### Findings
<Things you noticed from running the app. Lower the bar: if it made you pause, it goes here.
Not just bugs — friction, surprising defaults, unhelpful error messages, unexpected slowness.
⚠️ lines for anything worth interrupting the reviewer for; plain bullets for context.
Every 🔍 probe gets a finding line even when it passed.
Empty is fine if nothing stuck out — but nothing sticking out is rare.>
```

**Verdicts:**
- **PASS** — you ran the app, the change did what it should at its surface.
- **FAIL** — you ran it and it doesn't. Or it breaks something adjacent.
- **BLOCKED** — couldn't reach a state where the change is observable (build broke, missing dep, handle
  wouldn't come up). Say exactly where it stopped.
- **SKIP** — no runtime surface exists (docs-only, types-only, tests-only). One line why.

No partial pass. "3 of 4 passed" is FAIL until 4 passes or is explained away. When in doubt, FAIL —
false PASS ships broken code; false FAIL costs one more human look.

---

## Relationship to other skills

- **`agent-operating-principles` §2** covers *debugging* a bug — reproducing it, probing the live system.
  Verify covers *confirming a fix or feature* — intentional observation, not open-ended diagnosis.
- **`independent-expert-review`** is a static code panel. Verify is runtime. Run Verify *after* an
  independent-expert-review round: the panel finds defects, you fix them, Verify confirms the surface is
  clean at runtime.
- **`project-gates`** defines the automated CI gates (typecheck, build, tests). Those are the project's
  correctness baseline. Verify checks *feature correctness* at the surface — what a user would see — which
  gates cannot check.
