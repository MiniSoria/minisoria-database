# minisoria-database

PostgreSQL schema, migrations, and seeds for Mini Soria.

> Educational project. Not affiliated with or a reproduction of Soria. Fictional data only.

## Contents

- `migrations/` — extensions, schema, indexes, authority ranks
- `seeds/` — fictional healthcare companies, sources, documents, chunks, facts, conflicts

## Apply locally

Prefer `make postgres` from `infrastructure/` (init scripts apply migrations + seeds).

Manual (pgvector image required):

```bash
psql "$DATABASE_URL" -f migrations/001_extensions.sql
psql "$DATABASE_URL" -f migrations/002_schema.sql
psql "$DATABASE_URL" -f migrations/003_indexes.sql
psql "$DATABASE_URL" -f migrations/004_authority_seed.sql
psql "$DATABASE_URL" -f seeds/001_companies.sql
psql "$DATABASE_URL" -f seeds/003_demo_facts.sql
```

## Design invariants

1. Every `facts` row references `source_id`, `document_id`, and `evidence_chunk_id`.
2. Facts are never overwritten; use `superseded_at` / `supersedes_fact_id`.
3. Source authority lives in `source_authority_ranks`, not application constants.
4. Document dedup via `UNIQUE (source_id, content_hash)`.
