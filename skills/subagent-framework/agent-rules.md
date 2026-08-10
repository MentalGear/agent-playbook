**When about to write real code, or spawning a subagent** → `subagent-framework`
- Don't build in the main loop — delegate implementation by default. Exceptions: small changes
  (<~15 min / <~100 lines), and delegation that has already repeatedly failed (§1a/§1b).
- Long-running or multi-step delegations must emit interim progress at defined checkpoints, so you can
  tell "working" from "stuck" without waiting for the final return.
- Delegated agents report worse-than-expected first; orchestrators spot-check the load-bearing claims and
  observe gates themselves — never take an agent's prose as proof a gate passed.
