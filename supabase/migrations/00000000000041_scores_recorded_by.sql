-- Migration: 00000000000041_scores_recorded_by.sql
-- Add recorded_by column to scores table for audit trail
-- 
-- Purpose: Track which user entered the score
-- Spec: spec-dom-01-entities.md, spec-arch-04-score-entry.md
-- 
-- The referee or organizer who enters the score is recorded for audit.

-- ============================================
-- ADD COLUMN: recorded_by
-- ============================================

ALTER TABLE scores ADD COLUMN IF NOT EXISTS recorded_by UUID REFERENCES auth.users(id);

-- Add index for querying by recorder
CREATE INDEX IF NOT EXISTS idx_scores_recorded_by ON scores(recorded_by);

-- ============================================
-- UPDATE TRIGGER: Auto-set recorded_by on INSERT
-- ============================================

-- The trigger already validates scores, now we also set recorded_by
-- This requires modifying the existing trigger or creating a new one

CREATE OR REPLACE FUNCTION fn_set_score_recorder()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-set recorded_by to current user on INSERT
    IF TG_OP = 'INSERT' THEN
        NEW.recorded_by := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_score_recorder ON scores;
CREATE TRIGGER trg_set_score_recorder
BEFORE INSERT ON scores
FOR EACH ROW EXECUTE FUNCTION fn_set_score_recorder();

-- ============================================
-- ADD COMMENT
-- ============================================

COMMENT ON COLUMN scores.recorded_by IS 'User who entered the score. Set automatically via trigger from auth.uid(). Used for audit trail and RLS validation.';
