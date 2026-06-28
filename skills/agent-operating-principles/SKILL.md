---
name: agent-operating-principles
description: Cross-project working discipline for coding agents — research existing open source before building anything new; debug with the troubleshooting playbook (reproduce → measure the real path → probe → compare a working sibling → suspect framework edges → fix at the root + add a regression guard) instead of guess-and-patch; and keep the project's troubleshooting reference current by recording each hard-won finding. Project-agnostic method; the consuming repo names its own docs/ capture locations. Load before building something new, before debugging a non-obvious bug, and after burning real time on a gotcha.
user-invocable: false
---

# Agent operating principles

Project-agnostic working discipline for coding agents. Three habits that pay for themselves repeatedly:
**research before you build**, **debug by method not by guess**, and **write down what you learned**. The
consuming repo supplies the concrete locations (its research folder, its troubleshooting doc); this skill is
the method.

## 1. Research existing open source before building anything new

When a new component, feature, or capability is needed — anything non-trivial not already in the repo —
**research what already exists in the open-source ecosystem first.** Two acceptable outcomes:

- **Adopt:** reuse a library/module/component that fits.
- **Learn:** if nothing fits well enough to adopt, study how others solved it — architecture, accessibility,
  UX, the edge cases they handle — before writing your own.

Do this *before* designing or writing code, not after. **Capture the findings in a short doc** under the
project's research folder: the options considered, each one's license / maintenance health / fit, and a
**cited recommendation**, so the decision is reviewable later. Only build once you've established that
nothing suitable exists to adopt or adapt — and at the call site, note which options you checked and why
none fit.

## 2. Debug by method, not by guesswork — the troubleshooting playbook

When a reported bug **isn't obvious from the code**, don't guess-and-patch the symptom. Work the playbook:

1. **Reproduce** it deterministically first — a bug you can't trigger on demand, you can't confirm you fixed.
2. **Measure through the real path**, not a convenient proxy. Exercise the actual code path the user hits
   (the real reactive/render/request path, real data sizes), not an isolated micro-benchmark that can lie
   about where the cost or fault actually is.
3. **Probe the live system** — inspect real runtime state (the DOM, the actual values, the network, logs),
   not what you *assume* the state is.
4. **Compare against a working sibling** — a similar component/endpoint/path that behaves correctly. The
   delta between broken and working usually points straight at the cause.
5. **Suspect the framework edges** — once your own logic checks out, the fault is often at a
   framework/library boundary (a reactivity rule, a lifecycle quirk, a proxy/serialization surprise, a
   default you didn't set). Confirm against the framework's docs/skill rather than assuming.
6. **Fix at the root, then add a regression guard** — a test, assertion, or check that would have caught
   this. A fix with no guard invites the same bug back.

Skipping straight to step 6 with a guessed patch is the anti-pattern this exists to prevent.

## 3. Keep the troubleshooting reference current — record what you learned

Maintain **one troubleshooting reference** in the repo (the project names the file, e.g.
`docs/debug-troubleshooting.md`). It is the project's institutional memory for *"things that bit us and how
to avoid them"* — non-obvious framework/library footguns, performance cliffs, API surprises, and
environment/tooling traps. Two duties, equally important:

- **Read it first.** Whenever something behaves strangely, check this doc *before* re-deriving a diagnosis
  from scratch — the answer (or a strong lead) is often already written down.
- **Write to it after.** Whenever you burn real debugging time on a gotcha — a footgun, a perf cliff, an API
  surprise, a tooling/environment trap — **add a short entry the moment you understand it**, while the
  context is fresh. The bar is simple: *if it cost you time and would cost the next agent the same, it gets
  an entry.*

Keep each entry tight and reusable — **symptom → root cause → fix → how to avoid**. Write the symptom the
way you'd *search* for it (the error text, the surprising behavior), so future-you finds it by the thing you
notice, not the cause you don't yet know. Keep the doc **one coherent reference**: if a new entry doesn't
fit the existing structure, reorganize so it stays scannable rather than bolting on an orphan note.

This closes the loop on §2: the playbook is how you find a root cause; this is how the next agent skips the
hunt entirely.
