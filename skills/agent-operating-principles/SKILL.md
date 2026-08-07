---
name: agent-operating-principles
description: Use before building something new, before reaching for a JS/web-dev tool, before debugging a non-obvious bug, after burning real time on a gotcha, when deciding whether code needs tests, when a spike turns out to matter, and before locking in a decision that evidence will later be judged against. Six project-agnostic habits for coding agents — research existing open source and prior art before building, with extra weight for new architecture or load-bearing components and three reuse questions per option (§1); default to Bun for JS/TS tooling (§2); debug by the troubleshooting playbook instead of guess-and-patch (§3); keep the project's troubleshooting reference current by recording each hard-won finding (§4); test real (non-throwaway) code test-first, committing load-bearing spikes out of gitignored scratch as evidence rather than losing them (§5); and pre-commit decision criteria before the evidence exists, recording negatives as first-class results (§6). The host repo names its own research/troubleshooting doc locations.
user-invocable: false
version: 2.0.0
global_agent_file_hint: Survey prior art before building new architecture or load-bearing components — wire formats, encodings and protocols especially. Pre-commit decision criteria, each able to kill a named option, before the evidence exists. See agent-operating-principles §1/§6.
---

# Agent operating principles

Project-agnostic working discipline for coding agents. Six habits that pay for themselves repeatedly;
**load the relevant section for the moment you're in:**
- **§1 Research before you build** — when a new component/feature/capability is needed.
- **§2 Reach for Bun** — when you need a JS/TS package manager, script runner, or test runner.
- **§3 Debug by method** — when a reported bug isn't obvious from the code.
- **§4 Record what you learned** — after any gotcha that cost real debugging time.
- **§5 Test real code** — when code stops being a throwaway spike and becomes something you'll keep (and
  commit the spike itself, out of scratch, once it's load-bearing evidence).
- **§6 Pre-commit your decision criteria** — before gathering the evidence a decision will rest on.

> **Designing out issues by construction** (the elegance test, the ladder, the deconstruction exercise)
> moved to its own skill: **solve-by-construction**. Verifying that a fix actually holds — probing before
> filing, mutation-checking the fix, foreign vectors, benchmarks as instruments — lives in
> **verification-instruments**.

> **Parameterized skill — resolve these slots from the host repo (its `CLAUDE.md`):**
> - **Research-capture location** (§1) — where prior-art findings are written up (e.g. a `docs/research/`
>   folder).
> - **Troubleshooting reference** (§4) — the one doc that holds this repo's gotchas (e.g.
>   `docs/debug/troubleshooting.md`).

## 1. Research existing open source before building anything new

When a new component, feature, or capability is needed — anything non-trivial not already in the repo —
**research what already exists in the open-source ecosystem first.** This applies with extra weight to new
architecture and load-bearing components: the harder something is to reverse once other code depends on it,
the more a prior-art survey — open-source precedent, existing patterns already in this codebase, published
designs for the problem — pays for itself before you commit. Two acceptable outcomes:

- **Adopt:** reuse a library/module/component that fits.
- **Learn:** if nothing fits well enough to adopt, study how others solved it — architecture, accessibility,
  UX, the edge cases they handle — before writing your own.

Do this *before* designing or writing code, not after. **Capture the findings in a short doc** under the
project's research folder: the options considered, each one's license / maintenance health / fit, and a
**cited recommendation**, so the decision is reviewable later. Only build once you've established that
nothing suitable exists to adopt or adapt — and at the call site, note which options you checked and why
none fit.

**Ask three reuse questions of every system the survey returns** — "adopt or not" is too coarse, and the
second and third questions pay off even when the answer to the first is no:
1. **Integrate** — can we use a part of it directly, as a dependency?
2. **Lift** — can we take the approach, the architecture, or the edge cases they handle, and implement it
   ourselves?
3. **Reuse their tests** — can we run *their* test suite, vectors, or conformance corpus against our
   implementation? Foreign tests are the only instrument that catches misconceptions our own tests share
   (see **verification-instruments** §3), so this one is worth asking even about a system you'd never adopt.

**Bytes that cross a boundary are their own trigger.** A new encoding, wire format, serialization, or
protocol — anything that crosses a process/engine boundary or persists as a content address — warrants a
survey even when the design feels obvious and local. These have accumulated decades of documented hazards
(normalization, surrogates, canonicalization, length-prefix ambiguity); the ecosystem's specs usually name
the trap you're about to rediscover empirically, and rediscovering it costs far more than the read.

**Record negatives as first-class.** An option you rejected, with the reason, *is* a result — write it into
the research doc alongside what you chose. Without it the same option gets re-proposed and re-litigated on
each pass, at full cost, with no new evidence. "We looked at X; rejected because Y" is what stops that.

> Prior-art research is read-heavy, parallelizable, and easy to verify against sources — a prime candidate to
> **delegate** (see the `subagent-framework` skill), and the resulting recommendation is a good thing to put
> through an `independent-expert-review` panel before you commit to a build.

**Example: pre-indexed code search for large codebases.** Past a certain scale, sequential grep/read
exploration becomes the bottleneck a research pass should catch — a rough marker is **~50k+ LOC, or a
monorepo where agent-driven exploration is already doing many read passes per task.** Pre-indexed code-graph
search tools (e.g. CodeGraph — CLI only: `npm i -g @colbymchenry/codegraph`, then `codegraph init` and
`codegraph explore` / `query` / `node` / `callers` / `callees` / `impact` / `files` from the shell) are worth
evaluating at that point. Use the CLI surface only — don't wire it as an always-on MCP server; a CLI
invocation is bounded like any other shell tool call, a standing server is a different trust commitment. As
with any adopted tool, confirm current license and maintenance health before adopting (this section's own
bar, above).

## 2. Default web-dev toolchain — reach for Bun

When you need a JavaScript/TypeScript **tool** — a package manager, script runner, or test runner — default
to **[Bun](https://bun.sh)** (`bun install`, `bun run`, `bun test`, `bunx …`) over `npm`/`pnpm`/`yarn`/`npx`.
This is about which tool to *invoke*, not what to *build* — that's §1.

**Match the host first, though.** If the project already carries an npm/pnpm/yarn lockfile or a stated
toolchain, use that — a second lockfile is its own bug — so Bun is the default for *greenfield* JS tooling and
where the project hasn't committed to one. It's the toolchain the playbook's own examples use — the
`project-gates` gate examples (`bun run check`/`lint`/`test:unit`) and the known-good devcontainer in
`agent-repo-layout` (Bun as installer/PM; Node stays the runtime) — so staying on it keeps commands and CI
consistent. When you do deviate, note why in the project's gate manifest (`project-gates`) or next to its
lockfile.

## 3. Debug by method, not by guesswork — the troubleshooting playbook

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

## 4. Keep the troubleshooting reference current — record what you learned

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

This closes the loop on §3: the playbook is how you find a root cause; this is how the next agent skips the
hunt entirely.

## 5. Test real code — spikes are free, kept code is test-driven

Throwaway exploration needs no tests: spike freely to learn an API, try a layout, or prove an idea. But the
moment code becomes **real** — you'll keep it, ship it, something else will depend on it, or you're about to
refactor it — switch to **test-driven development**: write the failing test first, make it pass, then
refactor (red → green → refactor).

The threshold is **"real," not "big"**: a 20-line module other code calls is real; a 300-line scratch file
you'll delete is not. The tell is *permanence* — if it would hurt for this to silently break later, it needs
a test now, and writing that test first is the cheapest time to do it.

Test-*first*, not test-after: the test pins the intended behaviour before the implementation biases it,
forces a testable design, and hands you the regression guard from §3 (step 6) for free. Test-after tends to
test what you happened to build — and often never gets written. (This writes the `logic`
gate of the project's gate manifest — see the **project-gates** skill — which the `subagent-framework` flow
then runs; TDD just means you write it first and let it drive the design.)

### A load-bearing spike doesn't stay in scratch — commit it as evidence

The gitignored scratch space (see **agent-repo-layout**) is for work that is *genuinely* disposable. A spike
stops being disposable the moment something depends on it: it's the **evidence behind a decision**, a
benchmark or measurement someone will cite, a **reproduction** of a bug, or a prototype the design now
assumes. At that point it leaves scratch and gets **committed**, in the round that produced it:

- **Kept code** → its real home under source, test-first per the rule above.
- **The finding it proves** (benchmark numbers, the option that won, why) → the project's research folder.
- **A reproduction** → alongside the troubleshooting entry it backs (§4), so the next agent can re-run it.

Scratch is wiped without notice and never reviewed — anything left there is gone, and a claim whose evidence
is gone is just an assertion. The test is *dependence, not size*: if a decision, a doc, or a future agent
would have to re-derive it, it belongs in git. When in doubt, commit it — an unused committed file costs a
few diff lines; a lost one costs the whole investigation.

## 6. Pre-commit your decision criteria — before the evidence exists

When a decision will rest on evidence you haven't gathered yet — a benchmark, a spike, a survey, a trial —
**write the criteria down first**, while you still don't know which way they'll cut. Three rules make this
work:

- **Each criterion must be able to kill a named option.** "Should be fast" decides nothing. "If p99 exceeds
  N ms under workload W, option B is out" is a criterion — it names a threshold, a condition, and the
  option it would eliminate. If no plausible measurement would change your choice, you aren't running a
  decision, you're running a justification.
- **State your bias openly.** You usually have a preferred answer; writing it down ("I expect to land on
  A") is what lets a reader — and later you — weigh the conclusion against it. An unstated preference
  silently sets thresholds.
- **Record deviations rather than retrofitting thresholds.** When the evidence lands outside what you
  pre-committed to and you choose to go ahead anyway, that's legitimate — but write down *that you
  deviated and why*. Quietly moving the threshold to match the result destroys the whole instrument, and
  it's invisible in the final doc unless you say so.

The output is the same research doc as §1 — criteria first, then evidence, then the call — so the decision
stays reviewable by someone who wasn't there. **Negatives belong in it too** (§1): the options this
evidence killed are results worth keeping.

> Deciding *where* a fix belongs, rather than *which option* to take, is a different discipline — see the
> **solve-by-construction** skill (the ladder, the elegance test).
