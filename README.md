# claude-config

My personal Claude Code configuration — the working defaults that load on
every conversation, plus the user-level skills that encode my stack
conventions.

## What's here

- `CLAUDE.md` — user-level overlay loaded on every Claude Code session.
  Defines voice, decision-making, engineering principles, AI feature
  patterns, testing philosophy, schema/migration discipline, observability
  rules, code style, workflow rhythm, and things to never do.
- `skills/` — user-level Claude Code skills, each in its own directory
  with a `SKILL.md` frontmatter file. Skills load on demand based on
  their description-triggers.

## Skills

- **followup-detection** — captures deferred concerns to
  `docs/followups.md` when phrases like "we should follow up" or
  "worth revisiting" surface during work.
- **reaching-for-backend-patterns** — teaches the canonical Node
  backend layering (Fastify + Zod + Kysely + typed errors + Awilix DI)
  before any backend code gets written.
- **reaching-for-frontend-libraries** — teaches the canonical library
  for each React problem (forms, fetch, state, class-name variants,
  etc.) before any frontend code gets written.
- **bruno-collection-maintenance** — keeps the Bruno HTTP collection
  in sync with Fastify route changes in projects that have a `bruno/`
  directory.
- **mumen** — middle-tier planning workflow for unit-of-work tasks,
  between "just do it" and full superpowers planning.

## Bootstrap on a new machine

```bash
git clone https://github.com/Drubnerw98/claude-config.git ~/repos/claude-config
cd ~/repos/claude-config
./setup.sh
```

The script symlinks `CLAUDE.md` and each skill into `~/.claude/`. If
existing files are present, it backs them up to `~/.claude/backup-<date>/`
before symlinking. Restart Claude Code after running it.

## How to edit

Edit files inside `~/repos/claude-config/` — they're the source of truth.
The symlinks in `~/.claude/` reflect changes immediately. Commit and
push when ready.

```bash
cd ~/repos/claude-config
# edit CLAUDE.md or skills/...
git diff
git add -A
git commit -m "describe the change"
git push
```

## Why this exists

`~/.claude/CLAUDE.md` and user-level skills are persistent prompt
context — they shape Claude's behavior across every session. Versioning
them means I can iterate deliberately, see the history of how my working
defaults have evolved, and bootstrap a new machine in seconds instead
of recreating the file from memory.

It also makes the working defaults reviewable. A file that loads on
every conversation deserves the same care as any other piece of
shipped code.
