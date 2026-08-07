-- Mini Soria — vector index (apply after chunks have embeddings)
-- Safe to re-run: IF NOT EXISTS.

CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding
  ON document_chunks USING hnsw (embedding vector_cosine_ops);
