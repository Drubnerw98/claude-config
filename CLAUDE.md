# CLAUDE.md — drub's working defaults

User-level overlay. Project-level `CLAUDE.md` files override anything below.
Keep this file tight: it loads on every conversation.

## About me

Self-taught dev shipping portfolio projects toward startup / agency roles.
Strong product instincts; solid TypeScript + React + Node. Comfortable
shipping AI features end-to-end — structured output, multi-step flows,
extraction pipelines — not just consuming SDKs. Less depth on infra /
DevOps and ML / data-science fundamentals — over-explain there rather
than assume. Defending architectural decisions in interviews matters
as much as feature shipping — treat me like a senior collaborator who
appreciates pushback.

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
- **Brief plan before any multi-step work.** What you'll do, in what
  order, what you're choosing not to do. Doesn't have to be long —
  3-5 bullets. Gives me a chance to redirect before you've sunk
  effort into the wrong approach.

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

See `reaching-for-ai-features` skill — fires whenever AI call code is
touched. Covers Opus-first, Zod-as-tool, named failure modes, retry-
once-fail-loudly, blocking vs background, streaming rules, sampling rules
(model-dependent), per-call cost logging, prompt caching, evals.

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

See `reaching-for-database-patterns` skill — fires whenever schema or
migration code is touched. Covers Drizzle default, Kysely escape hatch,
editable SQL, numbered filenames, two-phase data-touching changes,
reference data vs seed fixtures, prod-apply confirmation.

## Observability and logging

See `reaching-for-observability` skill — fires whenever server logging,
error-handler middleware, request-ID propagation, or AI-call metadata is
touched. Covers Pino default, structured logs, log-level rules, request
IDs, throw-not-log, PII discipline. Browser-side `console.log` is fine.

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
- **Review your own diff before claiming done.** Read the change as if
  you're a reviewer seeing it cold. Catches accidentally-deleted code,
  stray debug statements, leftover TODO comments, and the "fixed the
  symptom not the cause" pattern. More bugs land in diffs than in
  typechecks.
- **Before changing a function signature, surface the call sites first.**
  Grep them, list them, agree on the migration plan — *then* change
  the signature. Avoids the "fixed one site, broke five others"
  pattern. Applies to renames, prop changes, return-type changes.
- **Commit at meaningful checkpoints.** Bare one-line subject; body if
  needed; trailer:
  `Co-Authored-By: Claude <noreply@anthropic.com>`
  (Model version omitted on purpose — would go stale at every bump.)
- **Push after green-lit work — no separate ask** (policy since
  2026-06-10). Once I've approved the work, commit-and-push is part of
  finishing it. Never force-push to main; warn me before anything
  history-rewriting.
- **Never amend a published commit.** Always new commit on top.
- **Never skip hooks** (`--no-verify`, `--no-gpg-sign`). Investigate the
  failure, fix the cause.
- **Never force push to main.** If I ask, warn me first.
- **PR descriptions: one-line summary, bullet list of what changed,
  test plan.** Body carries detail; title stays short. Reviewer
  should be able to skim the title and know what kind of change
  it is.

## Things to never do

- Hallucinate identifiers — URLs, model IDs, package versions, file
  paths, or anything else you'd be tempted to construct from training
  data. Specific failure modes: date-suffixed model IDs
  (`claude-sonnet-4-5-20250514`), blog post permalinks, framework
  changelog anchors. When in doubt, give me the search term, not a
  guessed link.
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

- **Stack**: TypeScript everywhere. Vite + React for SPAs. Fastify for
  the API (matches `reaching-for-backend-patterns` skill — Awilix DI,
  Zod request validation, typed errors). Drizzle for the DB layer
  (reach for Kysely only when queries fight Drizzle's API). Zod for
  validation. Clerk for auth on SaaS. Postgres on Neon. Tailwind for
  styling. Pino for logs.
- **Layout**: pnpm monorepo with `apps/` + `packages/`. Shared types in
  `packages/shared`. ESLint flat config + Prettier at the repo root.
- **Hygiene from day one**: `pnpm typecheck`, `pnpm lint`, `pnpm test`,
  `pnpm format` scripts. CI workflow that runs all four. Env validation
  via Zod at boot.
- Ask me before scaffolding if any of these are wrong for the project.
