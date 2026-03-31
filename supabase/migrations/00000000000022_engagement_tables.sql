-- ============================================================
-- Migration: 00000000000022_engagement_tables
-- Purpose:
--   Add Ranks and Achievements logic to the database.
-- ============================================================

BEGIN;

-- 1. RANKS ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'athlete_rank') THEN
        CREATE TYPE athlete_rank AS ENUM ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND');
    END IF;
END $$;

-- 2. UPDATE athlete_stats
ALTER TABLE athlete_stats 
ADD COLUMN IF NOT EXISTS rank athlete_rank DEFAULT 'BRONZE';

-- 3. ACHIEVEMENTS SCHEMA
CREATE TABLE IF NOT EXISTS achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL, -- e.g., 'FIRST_VICTORY'
    name TEXT NOT NULL,
    description TEXT,
    icon_slug TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS player_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(person_id, achievement_id)
);

-- Seed basic achievements
INSERT INTO achievements (code, name, description, icon_slug) VALUES
  ('FIRST_BLOOD', 'First Blood', 'You won your first competitive match!', 'sword-icon'),
  ('INVICTUS', 'Invictus', '5 consecutive wins in a single category.', 'lightning-icon'),
  ('GIANT_KILLER', 'Giant Killer', 'Beat an opponent with 200+ more ELO than you.', 'skull-icon'),
  ('CHAMPION', 'Championship Hero', 'Won a tournament final.', 'trophy-icon')
ON CONFLICT (code) DO NOTHING;

-- 4. TRIGGER: AUTO-RANK UPDATE
CREATE OR REPLACE FUNCTION update_athlete_rank()
RETURNS TRIGGER AS $$
BEGIN
    NEW.rank := CASE
        WHEN NEW.current_elo <= 1000 THEN 'BRONZE'::athlete_rank
        WHEN NEW.current_elo <= 1200 THEN 'SILVER'::athlete_rank
        WHEN NEW.current_elo <= 1400 THEN 'GOLD'::athlete_rank
        WHEN NEW.current_elo <= 1600 THEN 'PLATINUM'::athlete_rank
        ELSE 'DIAMOND'::athlete_rank
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_athlete_rank ON athlete_stats;
CREATE TRIGGER trg_update_athlete_rank
BEFORE INSERT OR UPDATE OF current_elo ON athlete_stats
FOR EACH ROW
EXECUTE FUNCTION update_athlete_rank();

COMMIT;
