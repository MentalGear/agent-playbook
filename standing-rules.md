# Standing rules

Self-contained instructions that hold on every turn. `scripts/sync-agent-skills.sh` writes these into the
`## Standing rules` section of a consumer's generated `.agents/AGENT_RULES.md`.

**A standing rule may not name a skill.** A line that points at a skill is a *route*, and routes belong in
the generated route list, where the generator owns their format so a compressed rule cannot drift from the
skill it came from. A standing rule has no source skill, so it has nothing to drift from — that is what
makes it safe to state in full here.

**Keep this file short.** The predecessor mechanism put one hint in every skill's frontmatter and grew from
59 to 586 words in two commits, because each author saw only their own line and nobody saw the total. One
curated file has a single owner and a visible total. `validate-skill.sh` caps it.

**Only bullets under `## Rules` are emitted**, verbatim, as list items. Anything above that heading is
documentation for maintainers and never reaches a consumer — so an example bullet here cannot leak into
every agent's always-loaded context.

## Rules

- Write in standard technical English: plain declarative sentences, terms defined at first use, one concern per paragraph or bullet, and no figure of speech carrying a rule on its own.
