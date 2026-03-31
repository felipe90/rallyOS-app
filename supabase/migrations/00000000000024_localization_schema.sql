-- ============================================================
-- Migration: 00000000000024_localization_schema
-- Purpose:
--   Add geography master table and link core entities to countries.
-- ============================================================

BEGIN;

-- 1. COUNTRIES MASTER TABLE
CREATE TABLE IF NOT EXISTS countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    iso_code TEXT UNIQUE NOT NULL, -- e.g. 'CO', 'AR', 'ES'
    name TEXT NOT NULL,
    currency_code TEXT, -- e.g. 'COP', 'ARS', 'EUR'
    flag_emoji TEXT, -- e.g. '🇨🇴'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. LINK PERSONS (Nationality)
ALTER TABLE persons 
ADD COLUMN IF NOT EXISTS nationality_country_id UUID REFERENCES countries(id);

-- 3. LINK CLUBS (Location)
ALTER TABLE clubs 
ADD COLUMN IF NOT EXISTS country_id UUID REFERENCES countries(id);

-- 4. LINK TOURNAMENTS (Event Location)
ALTER TABLE tournaments 
ADD COLUMN IF NOT EXISTS country_id UUID REFERENCES countries(id);

-- 5. TRIGGER: AUTO-INHERIT COUNTRY FROM CLUB (Optional helper)
CREATE OR REPLACE FUNCTION inherit_tournament_country()
RETURNS TRIGGER AS $$
DECLARE
    v_club_country_id UUID;
BEGIN
    -- Only try if country is not already set
    IF NEW.country_id IS NULL THEN
        -- Try to find the associated club via the organizer or tournament entry
        -- Since tournaments are often started by staff belonging to a club, 
        -- we can lookup the club tied to the tournament (if exists via a staff member)
        -- Simplified for now: Manual entry in MVP or auto-filled via App.
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
