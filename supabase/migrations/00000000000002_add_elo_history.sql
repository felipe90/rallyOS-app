-- Migration: Add elo_history table
-- Purpose: Track ELO rating changes for athletes across matches

-- ============================================
-- 1. CREATE ENUM TYPE
-- ============================================
CREATE TYPE elo_change_type AS ENUM ('MATCH_WIN', 'MATCH_LOSS', 'ADJUSTMENT');

-- ============================================
-- 2. CREATE TABLE
-- ============================================
CREATE TABLE elo_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE NOT NULL,
    sport_id UUID REFERENCES sports(id) ON DELETE CASCADE NOT NULL,
    match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
    previous_elo INTEGER NOT NULL,
    new_elo INTEGER NOT NULL,
    elo_change INTEGER NOT NULL,
    change_type elo_change_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. CREATE INDEXES
-- ============================================
CREATE INDEX idx_elo_history_person_sport ON elo_history(person_id, sport_id);
CREATE INDEX idx_elo_history_match ON elo_history(match_id);

-- ============================================
-- 4. ROW LEVEL SECURITY
-- ============================================
ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;

-- Read-only for authenticated users
CREATE POLICY "Elo history is read only for users" 
ON elo_history
FOR SELECT
USING (true);
-- Note: No INSERT policy is created. This blocks insertions from the RLS client.
-- Database triggers bypass RLS if they use the SECURITY DEFINER function.
