# Research — agent-playbook tooling

Design research and expert-review rounds for **this hub's own machinery** (the skill-vendoring / update
mechanism: `scripts/sync-agent-skills.sh`, `lib.sh`, `update-check.sh`, `build-registry.sh`,
`validate-skill.sh`, the registry, and the CI integrity gate). The accepted design decision lives in
[`../decisions/2026-06-30-vendoring-integrity-pivot.md`](../decisions/2026-06-30-vendoring-integrity-pivot.md).

> These rounds cover both the hub scripts and a consuming repo's mirror (they were conducted while hardening
> the mechanism end-to-end). They live here because the hub **owns** the mechanism.

| Doc | Covers |
|---|---|
| [`2026-06-30-update-mechanism-prior-art.md`](2026-06-30-update-mechanism-prior-art.md) | Prior art: how Claude skills + other update/vendoring mechanisms work; best practices to adopt |
| [`2026-06-30-update-mechanism-review.md`](2026-06-30-update-mechanism-review.md) | First panel on the (pre-pivot) update mechanism: first-pin automation + hardening findings |
| [`2026-07-01-vendoring-review.md`](2026-07-01-vendoring-review.md) | Round 1 (post-pivot): git-status gate wording, gate-script access tier, EXTERNAL_SKILLS, new-skill adoption |
| [`2026-07-01-vendoring-review-round2.md`](2026-07-01-vendoring-review-round2.md) | Round 2 (+ round-3 correction): the ancestry-gating change that was shipped then **reverted** as a regression |
| [`2026-07-01-vendoring-review-round4.md`](2026-07-01-vendoring-review-round4.md) | Round 4 (final-state panel): AGENT_PLAYBOOK_SRC asymmetry, rollback fail-open, test-coverage additions |
