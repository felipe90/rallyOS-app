-- ============================================================
-- Migration: 00000000000019_architectural_overhaul
-- Purpose: 
--   1. Normalize sets into match_sets table.
--   2. Implement deterministic bracket slots.
--   3. Refine player identity.
-- ============================================================

BEGIN;

-- ────────────────────────────────────────
-- 1. DETERMINISTIC BRACKET SLOTS
-- ────────────────────────────────────────

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bracket_slot') THEN
        CREATE TYPE bracket_slot AS ENUM ('A', 'B');
    END IF;
END $$;

ALTER TABLE matches 
ADD COLUMN IF NOT EXISTS winner_to_slot bracket_slot,
ADD COLUMN IF NOT EXISTS loser_to_slot bracket_slot;

COMMENT ON COLUMN matches.winner_to_slot IS 'Identifies which slot (A or B) the winner advances to in the next_match_id.';

-- ────────────────────────────────────────
-- 2. SETS NORMALIZATION
-- ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS match_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    set_number INTEGER NOT NULL,
    points_a INTEGER DEFAULT 0,
    points_b INTEGER DEFAULT 0,
    is_finished BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(match_id, set_number)
);

-- Data Migration: Move sets from JSONB to relational table
INSERT INTO match_sets (match_id, set_number, points_a, points_b, is_finished)
SELECT 
    match_id,
    (s->>'set')::INTEGER,
    (s->>'a')::INTEGER,
    (s->>'b')::INTEGER,
    TRUE -- Assume previous JSONB sets were finished
FROM scores,
jsonb_array_elements(sets_json) AS s
ON CONFLICT DO NOTHING;

-- Remove the obsolete column
ALTER TABLE scores DROP COLUMN IF EXISTS sets_json;

-- ────────────────────────────────────────
-- 3. IDENTITY REFINEMENT
-- ────────────────────────────────────────

-- Ensure 1:1 relationship between persons and users where applicable
ALTER TABLE persons DROP CONSTRAINT IF EXISTS persons_user_id_key;
ALTER TABLE persons ADD CONSTRAINT persons_user_id_key UNIQUE (user_id);

-- ────────────────────────────────────────
-- 4. CLEANUP OF OBSOLETE TRIGGERS (Stubs)
-- ────────────────────────────────────────
-- We will redefine these in subsequent migrations during Phase 2
DROP TRIGGER IF EXISTS trg_match_completion ON matches;
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;

COMMIT;
