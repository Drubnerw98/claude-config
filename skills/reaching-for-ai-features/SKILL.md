---
name: reaching-for-ai-features
description: Invoke any time you are about to write or edit code that calls an LLM — Anthropic/OpenAI SDK calls, structured-output pipelines, extraction/refinement/recommendation/consensus flows, tool-use loops, prompt construction, AI-touching service methods, AI-call logging, or evals. Teaches the canonical AI-feature defaults (Opus first, Zod-as-tool, named failure modes, retry-once-then-fail, blocking-vs-background, streaming rules, temperature defaults, per-call cost logging); you must consult before writing or extending any AI call even when a model or pattern was already chosen by the plan or surrounding code.
version: 1
metadata:
  type: reaching-for
---

# Reaching for AI features

## Overview

Most portfolio work has real AI in it — extraction, refinement, recommendation, consensus. The defaults below are the choices I've already defended on quality, cost, latency, and operability. When you reach for an AI call, **pause** — the canonical answer is almost always one of: Opus + Zod-as-tool + named failure modes + retry-once-then-fail + per-call cost log. Project-level `CLAUDE.md` may override; otherwise apply by default.

## When to use

You're about to write any of these:

- A new call to Anthropic / OpenAI / any LLM provider.
- A change to an existing prompt, tool schema, model ID, or temperature.
- A new structured-output extraction or classification flow.
- A new multi-step / tool-use loop.
- Anything that logs (or fails to log) AI call cost.
- An eval, fixture, or AI-call test.

**Don't use** for: code that consumes an already-built AI feature's output (downstream rendering, post-processing on validated data) — the AI boundary is the call site, not its consumers.

## Decision framework

| Problem | Default |
|---|---|
| **Model for new features** | Opus (match quality first, cost-optimize after ship) |
| **Structured output** | Zod schema + native tool use (Anthropic tool definitions / OpenAI function calling) |
| **Schema location** | `packages/shared/` if reused across server + client; otherwise colocated |
| **Retries** | Once with same params, then fail loudly |
| **Latency posture** | Sub-2s + reliable → block. Slower / flakier / batch → background job + status polling |
| **Streaming** | Stream chat / generation / rewrite. Skip for background jobs and structured-output tool calls |
| **Temperature** | Opus 4.7+ / Fable: omit entirely — sampling params are removed and 400. Sonnet / Haiku: eval-reproducible tasks → 0.2, else provider default |
| **Cost logging** | From day one: model, input/output tokens, cost in cents, feature-name tag, pinned model ID |
| **Prompt caching** | Skip until the feature has volume |
| **Eval coverage** | Lightweight fixture folder, run manually before prompt changes |

## Canonical patterns

### Opus first, optimize later

Don't propose Sonnet/Haiku swaps unsolicited even for "background" work. Match real output quality first; cost-optimize once the feature ships and traffic exists.

### Zod schema + native tool use

One Zod schema describes the tool input, validates the response at runtime, and lives in `packages/shared/` if reused. Don't hand-roll JSON schemas alongside Zod — generate the JSON schema from the Zod schema (or use the SDK helper) so there's one source of truth.

Validate every response with the same Zod schema that defined the tool. AI output is an external boundary — don't trust `model.parsedResponse` blindly; reparse and check.

### Failure-mode-by-name in prompts

When the model has a known failure mode, name it in a diagnostic phrase. *"Don't include items only to meet volume requirement"* beats 50 abstract instructions. Each named failure mode references a real prior regression, not a hypothetical — if you can't point to a past instance, don't add the line.

### Retry once with same params, then fail loudly

No silent retries, no fallback to a degraded result unless the feature is explicitly designed around degradation. Surface the failure to the user; let them trigger again or queue a retry. Catch-and-default makes AI bugs invisible.

### User-blocking vs background

| Shape | Posture |
|---|---|
| Sub-2s call, high success rate | Block the request |
| Slower / flakier / batch-shaped | Job + status polling |

Examples from my projects: Resonance's extraction is background; Ensemble's per-turn evaluation is blocking.

### Streaming rules

| Surface | Stream? |
|---|---|
| Chat responses, generations, rewrites | Yes — perceived-latency win is real and free |
| Background jobs | No — nobody's watching |
| Structured output via tool use | No — you need the whole response before parsing; streaming adds complexity for no UX gain |

### Temperature

- **Opus 4.7+ and Fable 5: don't send it.** `temperature` / `top_p` / `top_k`
  are removed on these models — the API returns a 400. Steer with the prompt
  and `output_config.effort` instead.
- **Sonnet / Haiku: 0.2 not 0** for extraction, classification, code gen,
  structured output, and anything you'd want to eval reproducibly. Pure 0 can
  trigger repetition loops in some patterns.
- **Provider default** for everything else.

### Multi-step loops

Only when the task genuinely needs steps. One well-crafted call with full context beats a chained orchestration most of the time. Reach for tool-use loops when there's real lookup / research / iteration to do. Don't build agentic architecture for one-shot tasks dressed up as multi-step.

### Per-call cost logging

Wire from day one — cheap when the call site is fresh, awful to retrofit. Capture:

```ts
logger.info({
  feature: 'resonance.extract',
  model: 'claude-opus-4-8',           // pinned, never claude-opus-latest
  inputTokens: usage.input_tokens,
  outputTokens: usage.output_tokens,
  costCents: computeCostCents(usage, 'claude-opus-4-8'),
  requestId,
}, 'ai call complete');
```

### Prompt caching

Skip until the feature has volume. Once a stable system prompt + few-shots get reused across thousands of requests, add cache breakpoints. Until then it's premature optimization.

### Evals

A small folder of fixture inputs + expected output shapes, run manually before shipping prompt changes. Not CI yet. Push toward golden datasets + automated diff reports when a feature actually has users and prompt churn.

## Common rationalizations

Stop and reconsider when you hear yourself thinking any of these:

| Rationalization | Reality |
|---|---|
| "This is background work, Haiku is fine" | Quality drift on background features is invisible until users notice. Ship on Opus, gather real outputs, then propose a downgrade with eval evidence. |
| "I'll just JSON.parse the response, the prompt says return JSON" | Models return invalid JSON, prose explanations before the JSON, or partial JSON on early termination. Tool use eliminates the failure class; "the prompt says" doesn't. |
| "I can hand-roll the JSON schema, Zod is overkill here" | You'll re-validate the response with Zod three weeks later when a downstream consumer breaks. Two schemas = two sources of truth = inevitable drift. One Zod schema, one place. |
| "Quiet retry-on-failure makes the feature more robust" | It makes failures invisible. The user can't tell the call slow-failed twice; you can't tell whether the prompt regression is real or noise. Fail loudly, surface to the user. |
| "Temperature 0 is the most deterministic, use it" | On Opus 4.7+/Fable the param is gone — sending it 400s. On Sonnet/Haiku, 0 can trigger repetition loops; 0.2 is the eval-reproducibility default, 0 is a debugging tool. |
| "I'll add cost logging once the feature is in prod" | You won't. The call site won't have request context, the model ID will be stale, the feature tag will be wrong, and you'll be retrofitting under deadline pressure. Wire it on the first commit. |
| "Let me add prompt caching while I'm here" | Caching pre-traffic is premature. The system prompt will change three more times before it stabilizes. Volume first, cache breakpoints second. |
| "An agent loop is more flexible than a single call" | Flexibility you don't need is complexity you have to debug. One well-shaped call with full context wins until there's real iteration / lookup / research to do. |
| "I'll add the eval fixture later" | The fixture costs five minutes when the prompt is fresh in your head, an hour when you've forgotten what edge case caused the regression. Add it now. |
| "Streaming the tool-use response will make it feel faster" | You can't parse the tool result until it's complete. Streaming buys nothing and adds parser complexity. Skip. |

## Red flags — pause and reconsult

- A model ID hard-coded as `claude-opus-latest` or any non-pinned alias.
- A `JSON.parse(response.content)` instead of Zod + tool use.
- A `try/catch` around the AI call that returns a default value on failure.
- Cost not logged at the call site (no `model`, `tokens`, `costCents` fields).
- Any sampling param sent to Opus 4.7+/Fable (400s), or temperature `0` (not `0.2`) on Sonnet/Haiku for a task you'd eval reproducibly.
- Prompt caching configured for a feature with no measurable volume yet.
- A multi-step loop where one well-shaped call would have done it.
- An eval fixture that asserts on output quality (those belong in evals, not the test suite — see Testing in CLAUDE.md).

Each signals the canonical default you should be reaching for instead.

## Spirit vs letter

This skill is about *defaulting to the AI patterns I've already defended* — Opus, Zod-as-tool, named failures, retry-once-fail-loudly, cost logging from day one. Skipping a default because "this case is special" without naming what's special is violating the skill. The whole point is consistency across features: every AI call in my projects logs the same fields, validates with the same library, fails the same way. That's what makes the system debuggable at 2am.

## Don't use as a hammer

- **Spikes and prompt experiments** in a notebook or scratch file — skip cost logging, skip eval scaffolding, just iterate. Promote to "real" only when the prompt is heading into a feature.
- **Codebases on a different AI SDK or provider** (OpenAI-only, Vertex-only, etc.) — apply the principles (structured output, retry posture, cost logging, named failure modes) without forcing Anthropic-specific patterns.
- **Existing projects with a project-level `CLAUDE.md` override** for any of these defaults — follow the project's choice, don't reintroduce the user-level default.
