# CLAUDE.md — drub's working defaults

User-level overlay. Project-level `CLAUDE.md` files override anything below.
Keep this file tight: it loads on every conversation.

## About me

Self-taught dev shipping portfolio projects toward startup / agency roles.
Strong product instincts; solid TypeScript + React + Node. Comfortable
shipping AI features end-to-end — structured output, multi-step flows,
extraction pipelines — not just consuming SDKs. Defending architectural
decisions in interviews matters as much as feature shipping — treat me
like a senior collaborator who appreciates pushback.

## How to talk to me

- Brief responses. State what's about to happen, run the work, summarize what
  changed. No padding, no running narration.
- Greenlights are short ("yeah", "send it", "go"). Don't ask for
  re-confirmation when I've already approved a plan.
- No emojis in regular communication.
- State results and decisions directly. End-of-turn summaries: 1-2 sentences.
- Surface uncertainty explicitly. When you're guessing, say so — false
  confidence costs more than the moment of "I'm not sure." Flag low
  confidence on library APIs, model behavior, framework version
  specifics, and anything else where you might be working from stale
  knowledge.

## How to make decisions

- **Push back when you disagree.** Saying yes to bad ideas is worse than
  friction. If I say "it's not gospel" that's an invitation to argue, not
  hedge.
- **Triage before doing on multi-item lists.** What you'll do, what you'll
  skip, what's already shipped. Catches duplicate work and design-review-
  from-an-old-screenshot situations.
- **Scope honesty over forced optimism.** If something's bigger than I think,
  say so before starting.
- **My pushback at the end of a list is signal.** Pay attention to what I
  add or push back on, not just the bullets I'm quoting.
- **Don't capitulate when I push back without an argument.** If I'm wrong,
  say why. If you're wrong, name what changed your mind.
- **Name the alternatives when proposing a library.** "Use Tanstack
  Query" is incomplete. "Tanstack Query over SWR because we need
  mutations and optimistic updates" surfaces the decision for me to
  challenge.

## Engineering principles to enforce

Apply by default. Flag when I deviate.

- **Schema as contract AND validator.** One Zod (or equivalent) schema
  constrains the API/AI generation surface AND runs at runtime as
  defense-in-depth. Same schema, both jobs.
- **Validate at boundaries, trust internals.** External APIs, user input,
  AI outputs — validate. Internal function signatures — trust the type
  system. No defensive `if (!x)` for things the types already prove.
- **Server-enforce, don't trust prompts or clients.** Toggles, rate limits,
  business rules — enforced in the service layer. The prompt or UI can
  also enforce them, but the server is the source of truth.
- **Defense-in-depth on auth.** Every user-scoped query filters by
  `user_id` explicitly, even past middleware that already gates access.
  Belt and suspenders.
- **Status-coded errors for user-state.** Throw `Error & { status: number }`
  for non-server faults (missing entity, rate limit, conflict, validation
  failure). Centralized error handler maps `.status` to the HTTP code.
- **Cache invalidation = delete-on-upstream-change.** When derived data is
  a pure function of upstream state, invalidate by deleting the cache row
  on upstream save. Don't try to keep them in sync incrementally.
- **`Promise.allSettled` when one failure shouldn't kill the batch.**
  External fan-out, multi-source aggregation — never `Promise.all` if one
  flaky source can take down the whole pipeline.
- **Rate-limit BEFORE the expensive call**, never after. Refuse the
  request, don't run it and fail to record.

## AI features

Most of my portfolio work has real AI in it (extraction, refinement,
recommendation, consensus). Defaults below apply unless project-level
CLAUDE.md overrides.

- **Opus first, optimize later.** Don't propose Sonnet/Haiku swaps
  unsolicited even for "background" work. Match real output quality
  first, cost-optimize once the feature ships and traffic exists.
- **Zod schema + native tool use** for any AI call with structured
  output. One Zod schema describes the tool input, validates the
  response at runtime, and lives in `packages/shared/` if reused
  across server + client. Don't hand-roll JSON schemas alongside Zod.
- **Failure-mode-by-name in prompts.** When the model has a known
  failure mode, name it in a diagnostic phrase. ("Don't include items
  only to meet volume requirement" beats 50 abstract instructions.)
  Each named failure mode references a real prior regression, not a
  hypothetical.
- **Retry once with same params, then fail loudly.** No silent retries,
  no fallback to a degraded result unless the feature is explicitly
  designed around degradation. Surface the failure to the user; let
  them trigger again or queue a retry.
- **User-blocking if latency is acceptable, background otherwise.**
  Sub-2s call with high success rate = block. Anything slower, flakier,
  or batch-shaped = job + status polling. Resonance's extraction is
  background; Ensemble's per-turn evaluation is blocking.
- **Stream when the user is watching text appear** — chat responses,
  generations, rewrites. The perceived-latency win is real and free.
  Skip streaming for background jobs (no one's watching) and for
  structured output via tool use (you need the whole response before
  parsing — streaming adds complexity for no UX gain).
- **Temperature: low for reproducibility, default otherwise.** Tasks
  you'd want to eval reproducibly — extraction, classification,
  structured output, code gen — use temp **0.2**, not 0. Pure 0 can
  trigger repetition loops in some patterns. Everything else trusts
  the model default.
- **Multi-step loops only when the task genuinely needs steps.** One
  well-crafted call with full context beats a chained orchestration
  most of the time. Reach for tool use loops when there's real
  lookup / research / iteration to do. Don't build agentic
  architecture for one-shot tasks dressed up as multi-step.
- **Log per-call cost from day one.** Cheap to wire when the call site
  is fresh; awful to retrofit. Capture model, input/output token
  counts, cost in cents, and a feature-name tag. Pin the model ID in
  the log (no `claude-opus-latest`).
- **Prompt caching: skip until the feature has volume.** Once a stable
  system prompt + few-shots get reused across thousands of requests,
  add cache breakpoints. Until then it's premature optimization.
- **Evals are lightweight but real.** A small folder of fixture inputs
  + expected output shapes, run manually before shipping prompt
  changes. Not CI yet. Push toward golden datasets + automated diff
  reports when a feature actually has users and prompt churn.
- **Schema-as-contract still applies.** AI output is an external
  boundary. Validate every response with the same Zod schema that
  defined the tool. Don't trust `model.parsedResponse` blindly —
  reparse and check.

## Testing

- **Unit for logic, integration for data flow.** Pure functions and
  business logic get fast colocated unit tests (`*.test.ts` next to
  the source). Anything that crosses the DB, ORM, queue, or external
  API gets an integration test that exercises the real stack — no
  mocked Drizzle/Kysely client, no mocked Postgres.
- **Mock external services and AI calls. Never mock our own code.**
  TMDB, Liveblocks, Anthropic, Firebase — mocked. Our own services,
  hooks, validators — used directly. Mocking internals teaches the
  test suite nothing the type system didn't already prove.
- **AI tests cover schema + prompt structure, not output quality.**
  Tests assert "given a well-formed model response, our handler
  parses + validates correctly" and "the prompt is shaped how we
  expect." Output quality is what the lightweight eval fixtures
  cover, not the test suite.
- **TDD gate: is there a clear, testable acceptance criterion?**
  If yes, write the test first.
  - **New features with a spec** — test-first forces you to define
    success before writing code. Highest-value case.
  - **Bug fixes** — reproduce-then-fix. The failing test pinned to
    the bug is what keeps it fixed.
  - **Refactors** — don't write new tests; existing tests gate the
    work. Test-first doesn't apply.
  - **Spikes, pure refactors, UI tweaks, the skip cases below** —
    TDD doesn't apply.
- **Skip writing tests for:**
  - Trivial passthroughs (getters, setters, re-exports, type-only
    utils — types already assert what the test would).
  - One-off scripts, migrations, experiments, throwaway harnesses.
  - UI components with no logic (presentational only — visual
    regression is the right tool, not Vitest).
- **Test the failure path, not just the happy path.** Bugs live in
  rejected inputs, expired tokens, partial failures, race conditions.
  A passing happy-path test on an untested error path is theater.
- **Vitest is the default.** `pnpm test` runs the suite; CI runs it
  on every PR. New projects scaffold with vitest from day one.

## Schema and migrations

- **Drizzle by default.** Schema-first ergonomics, migrations + types
  from one definition, readable SQL output (satisfies the editable-
  migrations principle). Resonance uses it; new projects start here.
- **Reach for Kysely when queries fight Drizzle's API** — heavy CTEs,
  window functions, dynamic query construction, or joining an existing
  DB where redefining the schema in TS is wasted work. Kysely and
  Drizzle can coexist in one project if needed.
- **Editable SQL migrations only.** Whatever tool generates them, the
  output should be plain SQL a human can read and patch. No ORMs or
  migration tools that hide what's about to run.
- **Numbered prefix + verb + subject** for migration filenames
  (`0007_add_user_themes.sql`). Easy to scan in commits; matches
  Drizzle's auto-generation pattern.
- **Two-phase as the default for data-touching changes.** Schema
  migration first, backfill as a separate migration. Each phase
  reversible; backfill re-runnable idempotently. The discipline is
  cheap and translates directly to production patterns later.
  - **Combine into one migration** for tiny tables (low row counts)
    where the backfill is trivial — the ceremony isn't worth it.
  - **Escalate to expand-contract** (add new column, dual-write,
    backfill async, drop old) when real traffic can't tolerate
    downtime or backfill could lock for minutes. Pattern to know,
    not to default to.
- **Reference data in migrations, dev fixtures in seed scripts.**
  Stable lookup tables (default categories, enum-as-table values,
  initial admin user) ship with the migration as idempotent INSERTs.
  Dev/test fixtures live in `seeds/` or equivalent, never shipped to
  prod.
- **Confirm before applying migrations against prod**, even additive
  ones. They mutate shared state — and "additive" is harder to back
  out than it looks once the app starts reading from the new column.

## Observability and logging

- **Pino is the default logger.** Server and any long-running scripts.
  No `console.log` in committed code outside `bin/` scripts.
- **Always structured logs.** `logger.info({ userId, action, latencyMs },
  'recommendation served')` — the message is the human-readable
  headline, fields carry everything else. Strings are for humans;
  fields are for the query interface you'll wish you had at 2am.
- **Log level rule:**
  - `info` — request boundaries, state changes, and anything you'd
    want to see in prod after a deploy. The audit trail.
  - `debug` — inner steps, intermediate values, hot-path counters.
    Off by default in prod.
  - `warn` — recoverable failure paths, retries, fallback usage.
  - `error` — the centralized error handler logs these. See below.
- **Request IDs are mandatory.** Every inbound request gets an ID at
  the entry middleware, propagated through logs and into any AI
  call's metadata. Lets you correlate "this user's slow recommendation"
  with "this Anthropic call took 12s" without manual stitching. Cheap
  to add early; awful to retrofit.
- **Errors are thrown, not logged at the throw site.** Throw a
  status-coded `Error & { status: number }`; the centralized error
  handler logs it once with full request context. Double-logging
  fragments the trail. Exception: at boundaries (queue consumers,
  cron jobs) where there's no handler above you — log + rethrow with
  context.
- **What NOT to log:** auth headers, raw user input that might carry
  PII, full AI prompts in production (token count + model + cost is
  enough), full request bodies for endpoints handling sensitive data.
  Logging is a data egress surface; treat it like one.

## Code style

- **Comments answer WHY, never WHAT.** Constraints, invariants, workarounds,
  surprising behavior, references to past incidents. If removing the
  comment wouldn't confuse a future reader, don't write it.
- **No premature abstraction.** Three similar lines beats a one-use helper.
  Abstractions earn their keep on the third reuse, not the first.
- **No error handling for impossible cases.** Don't validate what the type
  system proves. Don't add fallbacks for paths that can't happen.
- **No backwards-compat shims when you can just change the code.** Renamed
  `_unused`, re-exported types, "// removed" comments — delete instead.
- **TS preferences**: `import type` for type-only; `unknown` over `any`;
  `never` for exhaustiveness; brand types when correctness matters more
  than ergonomics; `as const` over enums.
- **Never `as any` to silence TS.** Fix the type, narrow with a guard,
  or surface the question. Escape hatches are tech debt by definition
  — every `as any` shipped today is a regression vector tomorrow.
- **Derive state, don't sync it.** If two pieces of state need to stay
  in lockstep, derive one from the other (`useMemo`, computed values).
  `useEffect` to sync state-to-state is a smell — there's almost
  always a derivation that removes the second source of truth.

## Workflow rhythm

- **Typecheck + (if frontend) build before claiming work done.** Failures
  the type system would catch are not allowed to leak into commits.
- **Before changing a function signature, surface the call sites first.**
  Grep them, list them, agree on the migration plan — *then* change
  the signature. Avoids the "fixed one site, broke five others"
  pattern. Applies to renames, prop changes, return-type changes.
- **Commit at meaningful checkpoints.** Bare one-line subject; body if
  needed; trailer:
  `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- **Never push to remote unless I ask.** Exception: mid-deploy debugging
  where the change has to be live to test, and I've already greenlit the
  approach.
- **Never amend a published commit.** Always new commit on top.
- **Never skip hooks** (`--no-verify`, `--no-gpg-sign`). Investigate the
  failure, fix the cause.
- **Never force push to main.** If I ask, warn me first.
- **PR descriptions: one-line summary, bullet list of what changed,
  test plan.** Body carries detail; title stays short. Reviewer
  should be able to skim the title and know what kind of change
  it is.

## Things to never do

- Generate URLs you're not certain of (model IDs from training, blog post
  permalinks, framework changelog anchors). When in doubt, give the search
  term, not a link.
- Construct date-suffixed model IDs from training data (e.g.
  `claude-sonnet-4-5-20250514`). Use the bare ID; check the Models API or
  ask if unsure.
- Run destructive shell commands (`rm -rf`, `git reset --hard`,
  `git push --force`, `DROP TABLE`) without explicit confirmation.
- Default to spinning up dev servers after edits. I prefer ship → push →
  test on prod. Only run `pnpm dev` / equivalent when there's a real
  reason to verify locally first (high regression risk, deploy debugging,
  in-flight session repro).
- Create planning / decision / summary `.md` files unprompted. Work from
  conversation context; don't litter the repo with intermediate docs.
- Commit a real `.env`. `.env.example` is tracked with placeholder
  values; actual secrets never enter the repo, even private ones.
- Reference a library's API without checking `package.json` first.
  Library versions drift faster than training data. Confirm the
  installed major version before writing code against it — especially
  Zod, Drizzle, Fastify, and anything in the AI SDK ecosystem.
- Silently fall back when an explicit decision failed. A feature flag
  check that errors should surface, not pretend it returned false.
  Catch-and-default makes bugs invisible.

## When starting greenfield work

If there's no project-level CLAUDE.md, default to:

- **Stack**: TypeScript everywhere. Vite + React for SPAs. Express or
  Fastify for the API (Express if you need long-lived process semantics
  like in-memory state, Fastify otherwise). Drizzle or Kysely for the DB
  layer. Zod for validation. Clerk for auth on SaaS. Postgres on Neon.
  Tailwind for styling. Pino for logs.
- **Layout**: pnpm monorepo with `apps/` + `packages/`. Shared types in
  `packages/shared`. ESLint flat config + Prettier at the repo root.
- **Hygiene from day one**: `pnpm typecheck`, `pnpm lint`, `pnpm test`,
  `pnpm format` scripts. CI workflow that runs all four. Env validation
  via Zod at boot.
- Ask me before scaffolding if any of these are wrong for the project.
