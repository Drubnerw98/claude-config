# claude-config

My personal Claude Code configuration — the working defaults that load on
every conversation, plus the user-level skills that encode my stack
conventions.

## What's here

- `CLAUDE.md` — user-level overlay loaded on every Claude Code session.
  Defines voice, decision-making, engineering principles, testing
  philosophy, code style, workflow rhythm, and things to never do.
  AI / schema / observability defaults live in their own trigger-loaded
  skills (see below) to keep the always-on file tight.
- `skills/` — user-level Claude Code skills, each in its own directory
  with a `SKILL.md` frontmatter file. Skills load on demand based on
  their description-triggers.
- `hooks/` — small shell scripts wired into Claude Code as `PreToolUse`
  hooks via `~/.claude/settings.json`. Block destructive git ops that
  prose rules can only suggest.

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
- **reaching-for-ai-features** — teaches the canonical AI-call defaults
  (Opus first, Zod-as-tool, named failure modes, retry-once-fail-loudly,
  per-call cost logging) before any AI call gets written or edited.
- **reaching-for-database-patterns** — teaches the canonical schema +
  migration discipline (Drizzle, editable SQL, numbered files, two-phase
  data-touching changes) before any schema or migration edit.
- **reaching-for-observability** — teaches the canonical server logging
  + error-handler shape (Pino, structured fields, request IDs,
  throw-not-log, PII discipline) before any log/error code gets written.
- **bruno-collection-maintenance** — keeps the Bruno HTTP collection
  in sync with Fastify route changes in projects that have a `bruno/`
  directory.
- **mumen** — middle-tier planning workflow for unit-of-work tasks,
  between "just do it" and full superpowers planning.

## Hooks

Each is a `PreToolUse` shell hook on `Bash`, wired in `~/.claude/settings.json`.

- **block-force-push-to-main.sh** — blocks `git push --force` / `-f` when
  the target branch (explicit refspec destination or current HEAD) is
  `main` or `master`. `--force-with-lease` is allowed.
- **block-amend-of-pushed-commit.sh** — blocks `git commit --amend` when
  HEAD is already reachable from the upstream tracking branch.

Hooks are referenced by absolute path from `~/.claude/hooks/`, which are
symlinks `setup.sh` creates back to this repo.

## Bootstrap on a new machine

```bash
git clone https://github.com/Drubnerw98/claude-config.git ~/repos/claude-config
cd ~/repos/claude-config
./setup.sh
```

The script symlinks `CLAUDE.md`, each skill, and each hook into
`~/.claude/`. If existing files are present, it backs them up to
`~/.claude/backup-<date>/` before symlinking. Restart Claude Code
after running it.

`settings.json` itself isn't versioned (it carries machine-specific
plugin state). To activate the hooks on a fresh machine, add the
following block to `~/.claude/settings.json`:

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "if": "Bash(git push*)",   "command": "/home/<you>/.claude/hooks/block-force-push-to-main.sh" },
        { "type": "command", "if": "Bash(git commit*)", "command": "/home/<you>/.claude/hooks/block-amend-of-pushed-commit.sh" }
      ]
    }
  ]
}
```

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
