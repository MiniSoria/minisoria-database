-- Mini Soria — demo companies + entity aliases
-- Fictional healthcare companies only. Not real issuers.

INSERT INTO companies (id, ticker, name, sector, industry, description, headquarters) VALUES
  ('11111111-1111-1111-1111-111111111101', 'ACME', 'Acme Therapeutics', 'Healthcare', 'Biotechnology',
   'Fictional clinical-stage biotech focused on immunology therapeutics.', 'Boston, MA'),
  ('11111111-1111-1111-1111-111111111102', 'NSTR', 'Northstar Health', 'Healthcare', 'Managed Care',
   'Fictional regional health system and care network.', 'Minneapolis, MN'),
  ('11111111-1111-1111-1111-111111111103', 'MRDN', 'Meridian Medical Devices', 'Healthcare', 'Medical Devices',
   'Fictional manufacturer of diagnostic and surgical devices.', 'San Diego, CA'),
  ('11111111-1111-1111-1111-111111111104', 'ATLS', 'Atlas Diagnostics', 'Healthcare', 'Diagnostics',
   'Fictional molecular diagnostics laboratory network.', 'Chicago, IL'),
  ('11111111-1111-1111-1111-111111111105', 'NOVA', 'NovaCare', 'Healthcare', 'Biotechnology',
   'Fictional specialty pharma focused on rare disease therapies.', 'Cambridge, MA')
ON CONFLICT (ticker) DO NOTHING;

-- Canonical entities (one per company)
INSERT INTO entities (id, entity_type, canonical_name, metadata) VALUES
  ('22222222-2222-2222-2222-222222222201', 'COMPANY', 'Acme Therapeutics', '{"ticker":"ACME"}'::jsonb),
  ('22222222-2222-2222-2222-222222222202', 'COMPANY', 'Northstar Health', '{"ticker":"NSTR"}'::jsonb),
  ('22222222-2222-2222-2222-222222222203', 'COMPANY', 'Meridian Medical Devices', '{"ticker":"MRDN"}'::jsonb),
  ('22222222-2222-2222-2222-222222222204', 'COMPANY', 'Atlas Diagnostics', '{"ticker":"ATLS"}'::jsonb),
  ('22222222-2222-2222-2222-222222222205', 'COMPANY', 'NovaCare', '{"ticker":"NOVA"}'::jsonb)
ON CONFLICT (entity_type, canonical_name) DO NOTHING;

-- Aliases for entity resolution demos (Acme variants)
INSERT INTO company_aliases (entity_id, company_id, alias, alias_normalized) VALUES
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101',
   'Acme Therapeutics', 'acme therapeutics'),
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101',
   'Acme Therapeutics Inc.', 'acme therapeutics inc'),
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101',
   'Acme Therapeutics, Inc.', 'acme therapeutics inc'), -- same normalized key — second insert skipped via unique
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101',
   'ACME', 'acme'),
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101',
   'ACME Therapeutics', 'acme therapeutics'),
  ('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111102',
   'Northstar Health', 'northstar health'),
  ('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111102',
   'Northstar Medical', 'northstar medical'),
  ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111103',
   'Meridian Medical Devices', 'meridian medical devices'),
  ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111103',
   'Meridian Diagnostics', 'meridian diagnostics'),
  ('22222222-2222-2222-2222-222222222204', '11111111-1111-1111-1111-111111111104',
   'Atlas Diagnostics', 'atlas diagnostics'),
  ('22222222-2222-2222-2222-222222222204', '11111111-1111-1111-1111-111111111104',
   'Atlas Health', 'atlas health'),
  ('22222222-2222-2222-2222-222222222205', '11111111-1111-1111-1111-111111111105',
   'NovaCare', 'novacare'),
  ('22222222-2222-2222-2222-222222222205', '11111111-1111-1111-1111-111111111105',
   'Nova Therapeutics', 'nova therapeutics')
ON CONFLICT (alias_normalized) DO NOTHING;
