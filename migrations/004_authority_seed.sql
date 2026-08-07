-- Mini Soria — configurable source authority ranks
-- Lower rank = higher authority. Editable without code changes.

INSERT INTO source_authority_ranks (source_type, rank, is_primary) VALUES
  ('SEC_FILING',        1, TRUE),
  ('COMPANY_REPORT',    2, TRUE),
  ('GOVERNMENT_DATA',   3, TRUE),
  ('PRESS_RELEASE',     4, FALSE),
  ('RESEARCH',          5, FALSE),
  ('NEWS',              6, FALSE),
  ('WEBSITE',           7, FALSE),
  ('SYNTHETIC',         8, FALSE)
ON CONFLICT (source_type) DO UPDATE
  SET rank = EXCLUDED.rank,
      is_primary = EXCLUDED.is_primary,
      updated_at = NOW();
