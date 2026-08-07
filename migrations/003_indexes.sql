-- Mini Soria — indexes
-- Educational project. Fictional data only. Not affiliated with Soria.

-- Companies / aliases
CREATE INDEX idx_companies_name_lower ON companies (lower(name));
CREATE INDEX idx_companies_industry ON companies (industry);
CREATE INDEX idx_company_aliases_company ON company_aliases (company_id);
CREATE INDEX idx_entities_type ON entities (entity_type);

-- Sources / documents
CREATE INDEX idx_sources_type ON sources (source_type);
CREATE INDEX idx_sources_published ON sources (published_at DESC NULLS LAST);
CREATE INDEX idx_documents_source ON documents (source_id);
CREATE INDEX idx_documents_status ON documents (processing_status);
CREATE INDEX idx_document_chunks_document ON document_chunks (document_id);
CREATE INDEX idx_document_chunks_tsv ON document_chunks USING GIN (tsv);

-- Vector ANN index is created in 005_vector_index.sql after embeddings exist.
-- Creating HNSW/IVFFlat on an all-NULL column is fragile across pgvector versions.

-- Facts
CREATE INDEX idx_facts_company_metric ON facts (company_id, metric);
CREATE INDEX idx_facts_company_metric_period ON facts (company_id, metric, period_end);
CREATE INDEX idx_facts_current ON facts (company_id, metric)
  WHERE superseded_at IS NULL;
CREATE INDEX idx_facts_source ON facts (source_id);
CREATE INDEX idx_facts_document ON facts (document_id);
CREATE INDEX idx_facts_evidence ON facts (evidence_chunk_id);
CREATE INDEX idx_facts_as_of ON facts (as_of_date DESC);

-- Changes / reconciliation
CREATE INDEX idx_fact_changes_company_detected ON fact_changes (company_id, detected_at DESC);
CREATE INDEX idx_fact_changes_detected ON fact_changes (detected_at DESC);
CREATE INDEX idx_reconciliations_company ON reconciliations (company_id, metric);
CREATE INDEX idx_reconciliations_pending ON reconciliations (resolution)
  WHERE resolution = 'PENDING_REVIEW';

-- Pipeline
CREATE INDEX idx_pipeline_jobs_status ON pipeline_jobs (status, created_at);
CREATE INDEX idx_pipeline_jobs_source ON pipeline_jobs (source_id);
CREATE INDEX idx_pipeline_events_job ON pipeline_events (job_id, created_at);
CREATE INDEX idx_pipeline_events_type ON pipeline_events (event_type, created_at DESC);

-- Watchlists / alerts / agent
CREATE INDEX idx_alerts_company ON alerts (company_id);
CREATE INDEX idx_alert_events_unread ON alert_events (created_at DESC) WHERE read_at IS NULL;
CREATE INDEX idx_agent_tool_calls_run ON agent_tool_calls (run_id, created_at);
CREATE INDEX idx_research_memos_company ON research_memos (company_id, created_at DESC);

-- Company FTS helper
ALTER TABLE companies ADD COLUMN IF NOT EXISTS tsv tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(ticker, '') || ' ' || coalesce(description, ''))
  ) STORED;
CREATE INDEX idx_companies_tsv ON companies USING GIN (tsv);

ALTER TABLE sources ADD COLUMN IF NOT EXISTS tsv tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(publisher, ''))
  ) STORED;
CREATE INDEX idx_sources_tsv ON sources USING GIN (tsv);
