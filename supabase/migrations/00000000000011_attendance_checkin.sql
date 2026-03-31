-- ============================================
-- SPEC-002: Attendance/Check-In
-- Add checked_in_at and attendance validation
-- ============================================

-- Add checked_in_at timestamp to tournament_entries
ALTER TABLE tournament_entries 
ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ;

-- Create function to validate attendance changes
CREATE OR REPLACE FUNCTION validate_attendance_change()
RETURNS TRIGGER AS $$
DECLARE
    v_tournament_status tournament_status;
    v_has_matches BOOLEAN;
BEGIN
    -- Get tournament status
    SELECT t.status INTO v_tournament_status
    FROM tournaments t
    JOIN categories c ON c.tournament_id = t.id
    WHERE c.id = NEW.category_id;

    -- Check if tournament is already LIVE (bracket generated)
    IF v_tournament_status = 'LIVE' THEN
        RAISE EXCEPTION 'Cannot change attendance after tournament has started';
    END IF;

    -- If marking as not attended, set status to CANCELLED
    IF OLD.status = 'CONFIRMED' AND NEW.status = 'CANCELLED' THEN
        -- Setting checked_in_at to NULL indicates not attended
        NEW.checked_in_at := NULL;
    END IF;

    -- If marking as attended, set checked_in_at timestamp
    IF NEW.checked_in_at IS NOT NULL AND OLD.checked_in_at IS NULL THEN
        NEW.status := 'CONFIRMED';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger fires BEFORE UPDATE on tournament_entries
DROP TRIGGER IF EXISTS trg_validate_attendance_change ON tournament_entries;
CREATE TRIGGER trg_validate_attendance_change
    BEFORE UPDATE ON tournament_entries
    FOR EACH ROW
    EXECUTE FUNCTION validate_attendance_change();
