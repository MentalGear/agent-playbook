---
name: agent-operating-principles
description: Use before building something new, before debugging a non-obvious bug, after burning real time on a gotcha, and when deciding whether code needs tests. Four project-agnostic habits for coding agents — research existing open source before building, defaulting to Bun for JS/web-dev tooling (§1); debug by the troubleshooting playbook instead of guess-and-patch (§2); keep the project's troubleshooting reference current by recording each hard-won finding (§3); and test real (non-throwaway) code test-first (§4). The host repo names its own research/troubleshooting doc locations.
user-invocable: false
version: 1.1.0
---

# Agent operating principles

Project-agnostic working discipline for coding agents. Four habits that pay for themselves repeatedly;
**load the relevant section for the moment you're in:**
- **§1 Research before you build** — when a new component/feature/capability is needed.
- **§2 Debug by method** — when a reported bug isn't obvious from the code.
- **§3 Record what you learned** — after any gotcha that cost real debugging time.
- **§4 Test real code** — when code stops being a throwaway spike and becomes something you'll keep.

> **Parameterized skill — resolve these slots from the host repo (its `CLAUDE.md`):**
> - **Research-capture location** (§1) — where prior-art findings are written up (e.g. a `docs/research/`
>   folder).
> - **Troubleshooting reference** (§3) — the one doc that holds this repo's gotchas (e.g.
>   `docs/debug/troubleshooting.md`).

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

> Prior-art research is read-heavy, parallelizable, and easy to verify against sources — a prime candidate to
> **delegate** (see the `subagent-framework` skill), and the resulting recommendation is a good thing to put
> through an `independent-expert-review` panel before you commit to a build.

**Default web-dev toolchain — reach for Bun.** The one standing exception to re-researching from scratch:
when what you need is a JavaScript/TypeScript **tool** — a runtime, package manager, test runner, bundler, or
script runner — default to **[Bun](https://bun.sh)** (`bun install`, `bun run`, `bun test`, `bunx …`) rather
than reaching for `npm`/`pnpm`/`yarn`/`node`/`npx`. It's the playbook's standardized toolchain: the
`project-gates` examples, the ship-a-working-devcontainer reference in `agent-repo-layout`, and the vendoring
docs all assume it, so staying on Bun keeps commands, lockfiles, and CI consistent across repos. Only deviate
when the **host repo already standardizes on a different toolchain** (respect what the project uses) or a
specific dependency genuinely doesn't run under Bun — and when you do, note why at the call site.

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
`docs/debug/troubleshooting.md`). It is the project's institutional memory for *"things that bit us and how
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

## 4. Test real code — spikes are free, kept code is test-driven

Throwaway exploration needs no tests: spike freely to learn an API, try a layout, or prove an idea. But the
moment code becomes **real** — you'll keep it, ship it, something else will depend on it, or you're about to
refactor it — switch to **test-driven development**: write the failing test first, make it pass, then
refactor (red → green → refactor).

The threshold is **"real," not "big"**: a 20-line module other code calls is real; a 300-line scratch file
you'll delete is not. The tell is *permanence* — if it would hurt for this to silently break later, it needs
a test now, and writing that test first is the cheapest time to do it.

Test-*first*, not test-after: the test pins the intended behaviour before the implementation biases it,
forces a testable design, and hands you the regression guard from §2 (step 6) for free. Test-after tends to
test what you happened to build — and often never gets written. (This writes the `logic`
gate of the project's gate manifest — see the **project-gates** skill — which the `subagent-framework` flow
then runs; TDD just means you write it first and let it drive the design.)
