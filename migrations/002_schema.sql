-- Mini Soria — core schema
-- Educational project. Fictional data only. Not affiliated with Soria.
-- Every fact MUST reference source + document + evidence chunk.

-- ---------------------------------------------------------------------------
-- Companies & entity resolution
-- ---------------------------------------------------------------------------

CREATE TABLE companies (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticker        TEXT NOT NULL,
  name          TEXT NOT NULL,
  sector        TEXT NOT NULL DEFAULT 'Healthcare',
  industry      TEXT NOT NULL,
  description   TEXT NOT NULL DEFAULT '',
  headquarters  TEXT NOT NULL DEFAULT '',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT companies_ticker_key UNIQUE (ticker)
);

CREATE TABLE entities (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type     TEXT NOT NULL
    CHECK (entity_type IN (
      'COMPANY', 'PRODUCT', 'DRUG', 'FACILITY', 'EXECUTIVE', 'MARKET', 'INDUSTRY'
    )),
  canonical_name  TEXT NOT NULL,
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT entities_type_name_key UNIQUE (entity_type, canonical_name)
);

CREATE TABLE company_aliases (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_id         UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  company_id        UUID REFERENCES companies(id) ON DELETE SET NULL,
  alias             TEXT NOT NULL,
  alias_normalized  TEXT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT company_aliases_normalized_key UNIQUE (alias_normalized)
);

-- ---------------------------------------------------------------------------
-- Sources & authority
-- ---------------------------------------------------------------------------

CREATE TABLE sources (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_type        TEXT NOT NULL
    CHECK (source_type IN (
      'SEC_FILING', 'COMPANY_REPORT', 'PRESS_RELEASE', 'GOVERNMENT_DATA',
      'NEWS', 'RESEARCH', 'WEBSITE', 'SYNTHETIC'
    )),
  publisher          TEXT NOT NULL,
  title              TEXT NOT NULL,
  url                TEXT,
  published_at       TIMESTAMPTZ,
  retrieved_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checksum           TEXT,
  credibility_score  NUMERIC(4,3) NOT NULL DEFAULT 0.500
    CHECK (credibility_score >= 0 AND credibility_score <= 1),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Configurable source authority (NOT hardcoded in business logic).
-- Lower rank = higher authority.
CREATE TABLE source_authority_ranks (
  source_type  TEXT PRIMARY KEY
    CHECK (source_type IN (
      'SEC_FILING', 'COMPANY_REPORT', 'PRESS_RELEASE', 'GOVERNMENT_DATA',
      'NEWS', 'RESEARCH', 'WEBSITE', 'SYNTHETIC'
    )),
  rank         INT NOT NULL CHECK (rank > 0),
  is_primary   BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Documents & chunks
-- ---------------------------------------------------------------------------

CREATE TABLE documents (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_id          UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  storage_key        TEXT NOT NULL,
  document_type      TEXT NOT NULL DEFAULT 'text',
  content_hash       TEXT NOT NULL,
  processing_status  TEXT NOT NULL DEFAULT 'DISCOVERED'
    CHECK (processing_status IN (
      'DISCOVERED', 'DOWNLOADING', 'PROCESSING', 'PROCESSED', 'FAILED'
    )),
  error_message      TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT documents_source_hash_key UNIQUE (source_id, content_hash)
);

CREATE TABLE document_chunks (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id   UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  chunk_index   INT NOT NULL CHECK (chunk_index >= 0),
  content       TEXT NOT NULL,
  page_number   INT CHECK (page_number IS NULL OR page_number > 0),
  embedding     vector(384),
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
  tsv           tsvector GENERATED ALWAYS AS (to_tsvector('english', content)) STORED,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT document_chunks_doc_idx_key UNIQUE (document_id, chunk_index)
);

-- ---------------------------------------------------------------------------
-- Facts (source-backed, historically versioned)
-- ---------------------------------------------------------------------------

CREATE TABLE facts (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id           UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  metric               TEXT NOT NULL,
  value                NUMERIC NOT NULL,
  unit                 TEXT NOT NULL,
  period_start         DATE,
  period_end           DATE,
  as_of_date           DATE NOT NULL,
  source_id            UUID NOT NULL REFERENCES sources(id),
  document_id          UUID NOT NULL REFERENCES documents(id),
  evidence_chunk_id    UUID NOT NULL REFERENCES document_chunks(id),
  confidence           NUMERIC(4,3) NOT NULL
    CHECK (confidence >= 0 AND confidence <= 1),
  extraction_method    TEXT NOT NULL DEFAULT 'SEED'
    CHECK (extraction_method IN ('RULE', 'LLM', 'HYBRID', 'SEED')),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  superseded_at        TIMESTAMPTZ,
  supersedes_fact_id   UUID REFERENCES facts(id),
  CONSTRAINT facts_evidence_required CHECK (evidence_chunk_id IS NOT NULL)
);

CREATE TABLE fact_changes (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  metric            TEXT NOT NULL,
  change_type       TEXT NOT NULL
    CHECK (change_type IN (
      'NEW_FACT', 'UPDATED_FACT', 'SUPERSEDED_FACT', 'CONFLICT', 'UNCHANGED'
    )),
  previous_fact_id  UUID REFERENCES facts(id),
  current_fact_id   UUID REFERENCES facts(id),
  previous_value    NUMERIC,
  current_value     NUMERIC,
  source_id         UUID REFERENCES sources(id),
  detected_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Reconciliation
-- ---------------------------------------------------------------------------

CREATE TABLE reconciliations (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id            UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  metric                TEXT NOT NULL,
  period_end            DATE,
  conflicting_facts     INT NOT NULL DEFAULT 0 CHECK (conflicting_facts >= 0),
  resolution            TEXT NOT NULL DEFAULT 'PENDING_REVIEW'
    CHECK (resolution IN (
      'PENDING_REVIEW', 'ACCEPTED_LATEST', 'ACCEPTED_AUTHORITY', 'DISMISSED'
    )),
  recommended_fact_id   UUID REFERENCES facts(id),
  reason                TEXT NOT NULL DEFAULT '',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE reconciliation_facts (
  reconciliation_id  UUID NOT NULL REFERENCES reconciliations(id) ON DELETE CASCADE,
  fact_id            UUID NOT NULL REFERENCES facts(id) ON DELETE CASCADE,
  PRIMARY KEY (reconciliation_id, fact_id)
);

-- ---------------------------------------------------------------------------
-- Pipeline observability
-- ---------------------------------------------------------------------------

CREATE TABLE pipeline_jobs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_type      TEXT NOT NULL
    CHECK (job_type IN ('INGEST', 'PROCESS', 'EXTRACT', 'RECONCILE')),
  source_id     UUID REFERENCES sources(id),
  document_id   UUID REFERENCES documents(id),
  company_id    UUID REFERENCES companies(id),
  status        TEXT NOT NULL DEFAULT 'QUEUED'
    CHECK (status IN ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'DEAD')),
  attempt       INT NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  last_error    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE pipeline_events (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id      UUID REFERENCES pipeline_jobs(id) ON DELETE SET NULL,
  event_type  TEXT NOT NULL
    CHECK (event_type IN (
      'ingestion_started', 'document_processed', 'facts_extracted',
      'facts_reconciled', 'conflict_detected', 'model_updated'
    )),
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Watchlists & alerts
-- ---------------------------------------------------------------------------

CREATE TABLE watchlists (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE watchlist_companies (
  watchlist_id  UUID NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  PRIMARY KEY (watchlist_id, company_id)
);

CREATE TABLE alerts (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  company_id   UUID REFERENCES companies(id) ON DELETE CASCADE,
  alert_type   TEXT NOT NULL
    CHECK (alert_type IN (
      'REVENUE_CHANGE', 'GUIDANCE_CHANGE', 'CLINICAL_TRIAL',
      'NEW_FILING', 'METRIC_CONFLICT'
    )),
  enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE alert_events (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alert_id    UUID NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL DEFAULT '',
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Research agent audit
-- ---------------------------------------------------------------------------

CREATE TABLE agent_runs (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  question                TEXT NOT NULL,
  status                  TEXT NOT NULL DEFAULT 'RUNNING'
    CHECK (status IN ('RUNNING', 'SUCCEEDED', 'FAILED', 'INSUFFICIENT_EVIDENCE')),
  answer                  TEXT,
  citations               JSONB NOT NULL DEFAULT '[]'::jsonb,
  insufficient_evidence   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at            TIMESTAMPTZ
);

CREATE TABLE agent_tool_calls (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  run_id          UUID NOT NULL REFERENCES agent_runs(id) ON DELETE CASCADE,
  tool_name       TEXT NOT NULL,
  arguments       JSONB NOT NULL DEFAULT '{}'::jsonb,
  result_summary  TEXT NOT NULL DEFAULT '',
  duration_ms     INT NOT NULL DEFAULT 0 CHECK (duration_ms >= 0),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE research_memos (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  content     JSONB NOT NULL,
  citations   JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
