-- ============================================================
-- Migration: 00000000000025_seed_countries
-- Purpose:
--   Populate the countries table with initial launch regions.
-- ============================================================

INSERT INTO countries (iso_code, name, currency_code, flag_emoji) VALUES
  ('CO', 'Colombia',  'COP', '🇨🇴'),
  ('AR', 'Argentina', 'ARS', '🇦🇷'),
  ('MX', 'México',    'MXN', '🇲🇽'),
  ('ES', 'España',    'EUR', '🇪🇸'),
  ('US', 'USA',       'USD', '🇺🇸'),
  ('BR', 'Brasil',    'BRL', '🇧🇷'),
  ('CL', 'Chile',     'CLP', '🇨🇱'),
  ('PE', 'Perú',      'PEN', '🇵🇪')
ON CONFLICT (iso_code) DO NOTHING;
