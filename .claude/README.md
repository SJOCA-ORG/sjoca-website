# .claude/

Shared Claude Code settings for this project, committed so everyone working on SJOCA
operates the same way.

**`settings.json`** — committed. Allows read-only inspection (listing, reading, searching,
`python3 -c` for survey analysis) and read-only git/gh commands without a prompt.
Anything that writes — edits, commits, pushes, repo changes — still prompts. Force-pushes
are denied outright, as is reading any raw survey directory.

**`settings.local.json`** — gitignored. Your own machine-specific overrides go here:
personal permissions, hooks pointing at scripts only you have, and so on. Nothing in this
file is shared, which is the point.

Project context for Claude lives in [`../CLAUDE.md`](../CLAUDE.md), not here. Keep that
file current — it's what a fresh session reads to find out where the project stands.
