---
name: reaching-for-database-patterns
description: Invoke any time you are about to write or edit anything that touches the schema, the migration directory, or the boot-time DB setup — new tables, columns, indexes, migration files, seed scripts, reference-data inserts, or anything that introduces a query against an existing schema. Teaches the canonical schema and migration defaults (Drizzle by default, editable SQL, numbered prefixes, two-phase data-touching changes, reference vs seed); you must consult before adding or editing migrations or schema files even when the ORM and migration tool are already chosen by the plan or surrounding code.
version: 1
metadata:
  type: reaching-for
---

# Reaching for database patterns

## Overview

Schema choices and migration shape are the hardest things to change later — once a column is named, indexed, and read by production code, renames cost weeks. The defaults below are what I reach for first so the cost of changing my mind stays low. When you reach for a schema edit or a migration, **pause** — the canonical answer is almost always one of: Drizzle, an editable SQL migration, a numbered filename, a two-phase change for anything that touches data.

## When to use

You're about to write any of these:

- A new table, column, index, constraint, or enum.
- A migration file (any tool's output).
- A backfill or data-rewrite script.
- A seed script or reference-data insert.
- A schema definition file (`schema.ts`, `models/*.ts`, etc.).
- Any change that mutates production data shape.

**Don't use** for: pure read-side query construction in a route or service — that's covered by `reaching-for-backend-patterns`.

## Decision framework

| Problem | Default |
|---|---|
| **ORM / query builder** | Drizzle |
| **Escape hatch for hard queries** | Kysely (heavy CTEs, window functions, dynamic SQL, joining an external schema) |
| **Migration format** | Editable plain SQL (no opaque ORM migrations) |
| **Filename convention** | `NNNN_verb_subject.sql` (e.g., `0007_add_user_themes.sql`) |
| **Data-touching change shape** | Two-phase: schema migration first, backfill as a separate migration |
| **Tiny-table data change** | One migration is fine — skip the two-phase ceremony |
| **High-traffic data change** | Expand-contract (add column, dual-write, async backfill, drop old) |
| **Reference data** | Idempotent INSERTs in the migration |
| **Dev / test fixtures** | `seeds/` directory, never shipped to prod |
| **Applying to prod** | Always confirm with the user first, even for additive changes |

## Canonical patterns

### Drizzle by default

Schema-first ergonomics, migrations + types from one definition, readable SQL output (satisfies the editable-migrations principle). New projects start here.

### Reach for Kysely when queries fight Drizzle's API

Heavy CTEs, window functions, dynamic query construction, or joining an existing DB where redefining the schema in TS is wasted work. Kysely and Drizzle can coexist in one project if needed — Drizzle for the schema + most queries, Kysely for the hard ones.

### Editable SQL migrations only

Whatever tool generates them, the output should be plain SQL a human can read and patch. No ORMs or migration tools that hide what's about to run. The rule is: before applying a migration, a human (or me) can open the file and know exactly what statements will execute.

### Filename convention

`NNNN_verb_subject.sql` — numbered prefix + verb + subject. Easy to scan in commits, matches Drizzle's auto-generation pattern, sorts cleanly in directory listings.

```
0006_add_users_table.sql
0007_add_user_themes.sql
0008_backfill_default_theme.sql
0009_add_theme_index.sql
```

### Two-phase data-touching changes

Schema migration first, backfill as a separate migration. Each phase reversible; backfill re-runnable idempotently. The discipline is cheap and translates directly to production patterns later.

```sql
-- 0010_add_users_timezone.sql  (phase 1: schema)
ALTER TABLE users ADD COLUMN timezone TEXT;

-- 0011_backfill_users_timezone.sql  (phase 2: data, idempotent)
UPDATE users
SET timezone = 'UTC'
WHERE timezone IS NULL;
```

**Combine into one migration** for tiny tables (low row counts) where the backfill is trivial — the ceremony isn't worth it for ~10 rows.

**Escalate to expand-contract** (add new column, dual-write, backfill async, drop old) when real traffic can't tolerate downtime or backfill could lock for minutes. Pattern to know, not to default to.

### Reference data vs dev fixtures

| Kind | Where | Shape |
|---|---|---|
| Stable lookup tables (default categories, enum-as-table values, initial admin user) | Migration file | Idempotent `INSERT ... ON CONFLICT DO NOTHING` |
| Dev / test fixtures (sample users, demo content) | `seeds/` directory | Run-on-demand script; never shipped to prod |

The test: would deleting this row break the app in production? If yes → migration. If no → seed.

### Confirm before applying to prod

Even additive migrations mutate shared state — and "additive" is harder to back out than it looks once the app starts reading from the new column. Always show the user the migration and confirm before running it against a prod database.

## Common rationalizations

Stop and reconsider when you hear yourself thinking any of these:

| Rationalization | Reality |
|---|---|
| "Prisma is more popular, why Drizzle?" | Drizzle gives editable SQL output; Prisma's migration format is opaque and hard to patch when something goes wrong. Editable SQL is the constraint, Drizzle is how I get it. |
| "Just use Drizzle for this CTE, it can probably handle it" | If you're already wrestling with the query builder API to express the SQL, you've left Drizzle's sweet spot. Kysely's chainable API is the escape hatch for exactly this. Mixing both in one project is fine. |
| "This backfill is tiny, I'll just stick it in the same migration as the schema change" | If the table is tiny too, fine. If the table has any size, separate phases let you re-run the backfill if it half-completes, and let you revert the data change without reverting the schema. |
| "It's additive, it can't break anything" | Until the app rolls out the read of the new column before the backfill finishes. Or the migration locks the table for 20 minutes. "Additive" is the riskiest false-safety story in schema work. |
| "I'll seed the lookup table in a startup script" | Then dev databases drift from prod, fresh boots have empty enums, and the "is this row supposed to exist?" question becomes ambiguous. Reference data lives in migrations. |
| "I'll just add the index inline with the column" | Fine for greenfield. Once the table has rows, `CREATE INDEX` can lock — pull it into its own migration so the failure mode is contained. |
| "This is just a rename, it's safe" | Renames on populated tables are migration-and-app-deploy choreography (rename + dual-read + drop). Always two-phase, often expand-contract. |
| "The ORM generated this migration, it must be right" | Generated migrations encode the ORM's assumptions, not yours. Read every line before applying. The "editable SQL" rule exists precisely so you can correct what the ORM got wrong. |

## Red flags — pause and reconsult

- A migration file the ORM generated that you haven't opened and read.
- A single migration that both alters schema *and* backfills a non-trivial number of rows.
- A reference-data insert in a startup script instead of a migration.
- A migration filename without a numbered prefix.
- A backfill statement that isn't idempotent (re-running it produces different state).
- A `prisma migrate deploy` / `drizzle-kit push` / equivalent against prod without confirmation.
- An ALTER on a populated table without thinking about lock behavior.
- A rename of a column or table without an expand-contract plan.

Each signals the canonical default you should be reaching for instead.

## Spirit vs letter

This skill is about *defaulting to the schema and migration discipline I've defended* — editable SQL, numbered files, two-phase changes for anything that touches data. Skipping the discipline because "this case is special" without naming what's special is violating the skill. Schema work is the highest-cost-to-undo work in any codebase; the ceremony is what keeps the cost low.

## Don't use as a hammer

- **One-off analytical queries** in a notebook or scratch script — no migration needed.
- **Throwaway prototypes** with no production deployment story — inline schema-and-seed is fine.
- **Existing projects with a different ORM or migration tool** (TypeORM, Prisma, raw SQL, Sequelize) — apply the principles (editable output, numbered files, two-phase for data) without forcing a Drizzle migration. If the project committed to Prisma, follow Prisma's idioms; don't introduce Drizzle alongside.
- **Project-level `CLAUDE.md` overrides** — follow the project's choice.
