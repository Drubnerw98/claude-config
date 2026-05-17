---
name: followup-detection
description: Use when noticing items during work that don't belong in current scope but shouldn't be lost — phrases like "we should follow up on X" or "worth revisiting Y", side tangents during brainstorming, deferred concerns in out-of-scope spec sections, small feature requests, gaps noticed during code review, Jira tickets containing "follow up" language. Captures the deferred item to <repo>/docs/followups.md so it survives being read cold months later.
version: 1
---

# Followup detection

## Why this exists

Substantial design work surfaces items that don't belong in the current scope but shouldn't be lost: side tangents during brainstorming, deferred concerns in spec out-of-scope sections, "we should think about X" moments, small feature requests, gaps noticed during code review. These need to land somewhere or they evaporate — and a thin bullet captures *that* an idea existed without preserving the analysis that made it interesting.

Aim for entries that survive being read cold months later.

## Where they live

Project-scoped, in `<repo>/docs/followups.md`. Versioned with the code so PR review can spot, add, and triage them. **Not** memory entries — memory is for user-level patterns (how I work, what I prefer); followups are project-scoped deferred work tied to specific code, tickets, or conversations.

## Triggers — watch for

- "We should follow up on X" / "worth revisiting Y" mid-conversation
- Side tangents that deserve their own focused thinking but don't fit current scope
- Small feature requests that aren't substantial enough to ticket immediately but shouldn't be lost
- Gaps noticed during code review that are out of scope for the current PR
- Jira tickets containing "follow up" or equivalent language
- Spec sections marked "out of scope" that name a *specific* deferred concern (not vague "future work" hand-waves)

## Action when noticed

1. Append a structured entry to `<repo>/docs/followups.md` under `## Active`, creating the file (with the scaffold below) if absent. Use the entry template — thin bullets become "dotted outlines of where an idea used to be" within weeks; useless when revisited.
2. Update the `## Contents` ToC with a link to the new entry.
3. Tell the user, one line: "noted in docs/followups.md".

## Entry template

Each entry is an `###` header so the ToC can link to it via GitHub's auto-anchor:

````markdown
### YYYY-MM-DD — short title

**What:** the gap or opportunity in one or two sentences.

**Why noticed:** what triggered surfacing this. PR/ticket sources can link out — the source carries the recoverable context. Conversation sources MUST summarize the surrounding context so "oh right, that thread" lands cold.

**Anchors:** file paths, ticket keys, PR numbers, dashboard views, session paths. What you'd grep for to re-orient.

**What's been considered:** alternatives discussed, tradeoffs surfaced, recommendations already formed. Skip when nothing was discussed.

**Shape of work:** rough decomposition — not a plan, just enough to size it ("small refactor in X" / "needs design pass on Y" / "two tickets, one for parser one for UI").

**Open questions:** things you'd need to decide before this could become a ticket. Skip when there are none.
````

## File scaffold

Use when creating `docs/followups.md` from scratch:

````markdown
# Followups

A queue between "noticed it" and "decided what to do about it." Items might become Jira tickets, get fixed inline during related work, or be explicitly abandoned. Triage periodically.

Format: see the followup-detection skill in ~/.claude/skills/followup-detection/.

## Contents

- [Active](#active)
- [Resolved](#resolved)
- [Abandoned](#abandoned)

## Active

(entries here, newest at top)

## Resolved

(items move here when ticketed and shipped, or fixed inline — keep for historical context, prune when the file gets long)

## Abandoned

(items move here when explicitly decided against — note the reason in a one-line addendum so the decision is recoverable)
````

## Maintenance rules

**ToC maintenance:** each entry's H3 title gets a child bullet under its parent section in `## Contents`. Use GitHub's slug rules (lowercase, spaces → `-`, em-dashes preserved as `--`, punctuation stripped) — easiest to copy the slug from the rendered view's "copy link" hover after a first commit if uncertain.

**Section transitions:** when an entry moves between Active / Resolved / Abandoned, update the ToC link too. When abandoning, append a one-line `**Abandoned YYYY-MM-DD:** reason.` to the entry body so future readers can recover the decision.

**Source-decay rule:** PR/ticket-sourced entries can be thin (the source is the recoverable context). Conversation-sourced entries MUST be self-contained — the conversation evaporates otherwise.

## At the start of substantial new work

Skim `docs/followups.md` for items relevant to the current task. Some may be ready to fold in; others worth flagging to the user before scoping.
