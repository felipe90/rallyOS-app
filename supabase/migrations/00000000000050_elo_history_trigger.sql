-- ============================================================
-- RALLYOS: Auto-populate elo_history Trigger
-- Migration: 00000000000050_elo_history_trigger.sql
-- ============================================================
-- Purpose: Create trigger to auto-populate elo_history table
-- whenever an athlete's ELO rating changes in athlete_stats.
--
-- This enables:
-- - Audit trail of ELO changes
-- - Prevention of ELO manipulation
-- - Calculation of trends over time
-- - Debugging ELO calculation issues
-- ============================================================

SET search_path TO extensions, public;

-- ─────────────────────────────────────────────────────────
-- 1. Add last_match_id column to athlete_stats
-- This column tracks which match caused the last ELO change
-- ─────────────────────────────────────────────────────────

ALTER TABLE athlete_stats 
ADD COLUMN IF NOT EXISTS last_match_id UUID REFERENCES matches(id) ON DELETE SET NULL;

COMMENT ON COLUMN athlete_stats.last_match_id IS 
    'UUID of the match that caused the last ELO change. Used by elo_history trigger.';

-- ─────────────────────────────────────────────────────────
-- 2. Create trigger function
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_record_elo_change()
RETURNS TRIGGER AS $$
DECLARE
    v_match_id UUID;
    v_change_type elo_change_type;
BEGIN
    -- Only record if current_elo changed
    IF OLD.current_elo != NEW.current_elo THEN
        -- Get match_id from the column we added
        v_match_id := NEW.last_match_id;
        
        -- Determine change type based on direction
        IF NEW.current_elo > OLD.current_elo THEN
            v_change_type := 'MATCH_WIN';
        ELSIF NEW.current_elo < OLD.current_elo THEN
            v_change_type := 'MATCH_LOSS';
        ELSE
            v_change_type := 'ADJUSTMENT';
        END IF;
        
        -- Insert history record
        INSERT INTO elo_history (
            person_id,
            sport_id,
            match_id,
            previous_elo,
            new_elo,
            elo_change,
            change_type
        ) VALUES (
            NEW.person_id,
            NEW.sport_id,
            v_match_id,
            OLD.current_elo,
            NEW.current_elo,
            NEW.current_elo - OLD.current_elo,
            v_change_type
        );
        
        -- Clear last_match_id after recording (to prevent duplicate entries)
        NEW.last_match_id := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────
-- 3. Create trigger
-- ─────────────────────────────────────────────────────────

-- Drop existing trigger if exists (for idempotency)
DROP TRIGGER IF EXISTS trg_record_elo_change ON athlete_stats;

-- Create trigger on current_elo changes
CREATE TRIGGER trg_record_elo_change
BEFORE UPDATE OF current_elo ON athlete_stats
FOR EACH ROW
EXECUTE FUNCTION fn_record_elo_change();

-- ─────────────────────────────────────────────────────────
-- 4. Ensure elo_history RLS policies exist
-- ─────────────────────────────────────────────────────────

-- Enable RLS if not already enabled
ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if exists (for idempotency)
DROP POLICY IF EXISTS "Users can view own ELO history" ON elo_history;
DROP POLICY IF EXISTS "Organizers can view tournament ELO history" ON elo_history;

-- Create SELECT policy for users to view their own history
CREATE POLICY "Users can view own ELO history"
ON elo_history FOR SELECT TO authenticated
USING (
    person_id IN (
        SELECT id FROM persons WHERE user_id = auth.uid()
    )
);

-- Create SELECT policy for organizers to view all history in their tournaments
-- Path: elo_history -> athlete_stats (by person_id) -> tournaments (by sport_id) -> tournament_staff
CREATE POLICY "Organizers can view tournament ELO history"
ON elo_history FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM athlete_stats ast
        JOIN tournaments t ON t.sport_id = ast.sport_id
        JOIN tournament_staff ts ON ts.tournament_id = t.id
        WHERE ast.person_id = elo_history.person_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);

-- ─────────────────────────────────────────────────────────
-- 5. Create function to manually record ELO change
-- (useful for adjustments not triggered by match)
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION record_elo_adjustment(
    p_person_id UUID,
    p_sport_id UUID,
    p_new_elo INTEGER,
    p_reason TEXT DEFAULT 'MANUAL_ADJUSTMENT'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_previous_elo INTEGER;
    v_change_type elo_change_type;
BEGIN
    -- Get current ELO
    SELECT current_elo INTO v_previous_elo
    FROM athlete_stats
    WHERE person_id = p_person_id AND sport_id = p_sport_id;

    -- Determine change type
    IF p_new_elo > v_previous_elo THEN
        v_change_type := 'TOURNAMENT_BONUS';
    ELSIF p_new_elo < v_previous_elo THEN
        v_change_type := 'ADJUSTMENT';
    ELSE
        -- No change, just return
        RETURN TRUE;
    END IF;

    -- Insert history record
    INSERT INTO elo_history (
        person_id,
        sport_id,
        match_id,
        previous_elo,
        new_elo,
        elo_change,
        change_type
    ) VALUES (
        p_person_id,
        p_sport_id,
        NULL,  -- No match for manual adjustments
        v_previous_elo,
        p_new_elo,
        p_new_elo - v_previous_elo,
        v_change_type
    );

    -- Update athlete_stats
    UPDATE athlete_stats
    SET current_elo = p_new_elo,
        updated_at = NOW()
    WHERE person_id = p_person_id AND sport_id = p_sport_id;

    RETURN TRUE;
END;
$$;

-- ============================================================
-- NOTE: Verification queries removed from migration file.
-- Run these manually for debugging:
--   psql ... -c "SELECT * FROM elo_history ORDER BY created_at DESC LIMIT 5;"
--   psql ... -c "SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%';"
-- END OF MIGRATION
-- ============================================================
