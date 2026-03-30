-- ============================================
-- rallyOS: Fix Offline Sync Conflict Resolution Triggers
-- ============================================
-- This migration ensures triggers are attached to matches and scores tables
-- for offline sync conflict resolution (last-write-wins + time-tampering protection)
--
-- Note: These triggers are already defined in 00000000000001_security_policies.sql
-- This migration serves as a safeguard and explicit idempotent fix

-- Ensure function exists ( idempotent )
CREATE OR REPLACE FUNCTION check_offline_sync_conflict()
RETURNS TRIGGER AS $$
BEGIN
    -- Block devices with fraudulently advanced time (Time-Tampering)
    IF NEW.local_updated_at > NOW() + INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'Timestamp in the future is not allowed (Time-Tampering protection)';
    END IF;

    -- If the incoming record is older than the one we already have, silently abort the update
    IF NEW.local_updated_at < OLD.local_updated_at THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist (for idempotency)
DROP TRIGGER IF EXISTS trg_matches_conflict_resolution ON matches;
DROP TRIGGER IF EXISTS trg_scores_conflict_resolution ON scores;

-- Create trigger for matches table
CREATE TRIGGER trg_matches_conflict_resolution
BEFORE UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION check_offline_sync_conflict();

-- Create trigger for scores table
CREATE TRIGGER trg_scores_conflict_resolution
BEFORE UPDATE ON scores
FOR EACH ROW
EXECUTE FUNCTION check_offline_sync_conflict();
