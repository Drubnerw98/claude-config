---
name: reaching-for-observability
description: Invoke any time you are about to write or edit logging, error-handling middleware, request-ID propagation, log-level decisions, or anything that produces a log line in a server / long-running script — including `console.log`, logger setup, the centralized error handler, queue-consumer logging, and AI-call metadata. Teaches the canonical observability defaults (Pino, structured logs, request IDs, throw-not-log, log-level rules, PII discipline); you must consult before writing or editing any of those even when a logger is already wired up in the surrounding code.
version: 1
metadata:
  type: reaching-for
---

# Reaching for observability

## Overview

Observability decisions made when the code is fresh are cheap; retrofits are expensive and incomplete. The defaults below give every server I work on the same shape: Pino, structured fields, a request ID threaded through everything, errors thrown once and logged once. When you reach for a log line or an error handler, **pause** — the canonical answer is almost always one of: structured Pino call at the right level, throw a status-coded error and let the central handler log it, or carry the request ID through the call.

## When to use

You're about to write any of these on the server side:

- A `console.log` / `console.error` / `console.warn`.
- A logger import or logger instantiation.
- A `try/catch` that logs.
- An error-handler middleware (Fastify `setErrorHandler`, Express error middleware, etc.).
- A request-ID middleware or any code reading / forwarding a correlation ID.
- An AI call site (request ID + cost fields should flow through).
- A queue consumer, cron job, or any boundary-level entry point.

**Don't use** for: browser-side `console.log` (see carve-out below) or scripts under `bin/` where `console` is the user-facing output channel.

## Decision framework

| Problem | Default |
|---|---|
| **Logger** | Pino |
| **Log shape** | Always structured: `logger.info({ ...fields }, 'headline')` |
| **`info`** | Request boundaries, state changes, anything you'd want to see in prod after a deploy |
| **`debug`** | Inner steps, intermediate values, hot-path counters; off by default in prod |
| **`warn`** | Recoverable failure paths, retries, fallback usage |
| **`error`** | Centralized error handler only — never at the throw site |
| **Errors** | Throw a status-coded `Error & { status: number }`; central handler logs once with request context |
| **Boundary exception** | Queue consumers / cron jobs with no handler above them: log + rethrow with context |
| **Request IDs** | Mandatory; assigned at entry middleware, propagated through logs and AI-call metadata |
| **PII in logs** | Never log auth headers, raw user input that may carry PII, full AI prompts in prod, or full request bodies for sensitive endpoints |

## Canonical patterns

### Pino is the default

Server and any long-running script. No `console.log` in committed server code outside `bin/` scripts.

```ts
// src/logger.ts
import pino from 'pino';
export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
});
```

### Structured logs, always

```ts
logger.info(
  { userId, action: 'recommendation.served', latencyMs, requestId },
  'recommendation served',
);
```

The message string is the human-readable headline. Fields carry everything else. Strings are for humans; fields are for the query interface you'll wish you had at 2am.

### Log-level rules

| Level | Use for |
|---|---|
| `info` | Request boundaries, state changes, audit trail — what you'd want to see in prod after a deploy |
| `debug` | Inner steps, intermediate values, hot-path counters. Off by default in prod |
| `warn` | Recoverable failure paths, retries, fallback usage |
| `error` | **Centralized error handler only.** See below |

### Request IDs are mandatory

Every inbound request gets an ID at the entry middleware, propagated through logs and into any AI call's metadata. Lets you correlate "this user's slow recommendation" with "this Anthropic call took 12s" without manual stitching. Cheap to add early; awful to retrofit.

```ts
// Fastify
app.addHook('onRequest', async (req) => {
  req.id = req.headers['x-request-id'] ?? randomUUID();
});

// AI call
await anthropic.messages.create({
  ...,
  metadata: { user_id, request_id: req.id },
});
```

### Errors are thrown, not logged at the throw site

Throw a status-coded `Error & { status: number }`; the centralized error handler logs it once with full request context. Double-logging fragments the trail.

**Boundary exception:** queue consumers, cron jobs, or any entry point where there's no handler above you — log + rethrow with context, since the rethrow has nowhere to go.

```ts
// Service code — throw, don't log
if (!recipe) {
  const err: Error & { status?: number } = new Error('recipe not found');
  err.status = 404;
  throw err;
}

// Centralized handler — log once
app.setErrorHandler((err, req, reply) => {
  req.log.error({ err, requestId: req.id }, 'request failed');
  reply.code(err.status ?? 500).send({ error: err.message });
});

// Queue consumer boundary — log + rethrow
worker.on('failed', (job, err) => {
  logger.error({ err, jobId: job.id, jobName: job.name }, 'job failed');
  throw err;
});
```

### What NOT to log

- Auth headers (Authorization, cookies).
- Raw user input that might carry PII.
- Full AI prompts in production (token count + model + cost + feature tag is enough — see `reaching-for-ai-features`).
- Full request bodies for endpoints handling sensitive data.

Logging is a data egress surface; treat it like one. If a log line went to a third-party log sink, would you be OK with what it contains?

## Frontend carve-out

`pino` doesn't run in browsers. Frontend code (React components, hooks, browser-side utilities) can use `console.log` / `console.error` / `console.warn` legitimately — that's the browser's logging channel. The "no `console.log` outside `bin/`" rule applies to server code.

For frontend, prefer to keep production `console.log` minimal — error reporting goes through whatever error-tracking SDK the project has (Sentry, etc.), not `console`.

## Common rationalizations

Stop and reconsider when you hear yourself thinking any of these:

| Rationalization | Reality |
|---|---|
| "I'll add the request ID later" | The call sites won't have it in scope, the AI-call metadata will be already-shipped, and you'll be stitching by timestamp at 2am. Add it on day one. |
| "Logging here AND in the central handler is belt-and-suspenders" | It's noise + fragmented traces. Every duplicate log line wastes a search session. Throw once, log once. |
| "`console.log` is fine, I'll convert later" | "Later" never comes; `console.log` ships to production. Pino from the first log line. |
| "A string log message is more readable" | Until you need to filter by user ID across 50k lines. Structured fields cost nothing extra and unlock the log interface. |
| "I'll log the full request body for debugging" | Until the body contains an OAuth token or a card number. Sensitive surfaces never get full-body logs; log specific fields you actually need. |
| "Let me just log this AI prompt to see what we're sending" | In dev: fine. In prod: never. Token count + model + cost + feature tag is the prod-safe shape. |
| "I'll use `info` for this debug-y thing because debug is too low" | If it's debug-y, it's `debug`. Mis-leveling pollutes the info stream that's actually your audit trail. |
| "I'll add a structured error class later" | `throw new Error('not found')` becomes "where did this 500 come from?" three deploys later. The status-coded throw is the same line count and instantly traceable. |

## Red flags — pause and reconsult

- A `console.log` in server-side code (outside `bin/`).
- A `try/catch` that calls `logger.error(...)` *and* rethrows — pick one.
- An error logged at the throw site AND in the central handler.
- An AI call without the request ID in its metadata.
- A log line with the full request body, auth header, or raw AI prompt in production.
- A `logger.info` for something that's actually debug-y (or vice versa).
- A `throw new Error('...')` without a status code in a service that has a central handler expecting them.
- A queue/cron consumer that swallows errors with neither log nor rethrow.

Each signals the canonical default you should be reaching for instead.

## Spirit vs letter

This skill is about *defaulting to the observability shape I've already defended* — Pino, structured fields, one log line per error, request IDs everywhere. Skipping a default because "this is just a quick debug log" without naming why is violating the skill. The whole point is that every server I work on has the same observability surface; that's what makes any one of them debuggable when something breaks.

## Don't use as a hammer

- **Scripts under `bin/`** where `console` is the user-facing output channel — `console.log` is correct there.
- **Browser-side code** — see the frontend carve-out above.
- **Throwaway one-off scripts** — Pino is overkill for a 20-line migration backfill.
- **Existing projects with an established logger** (winston, bunyan, the framework's default) — apply the principles (structured fields, request IDs, throw-not-log, level discipline, PII rules) without forcing Pino in alongside.
- **Project-level `CLAUDE.md` overrides** — follow the project's choice.
