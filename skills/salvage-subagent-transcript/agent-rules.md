**When a subagent goes stale, crashes, or returns nothing usable** → `salvage-subagent-transcript`
- Salvage before relaunching: the transcript and its workspace usually hold most of the work.
- Never spawn a fresh agent over a half-finished one — resume it, or harvest its diff and close it out.
