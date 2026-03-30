-- ============================================
-- rallyOS: Security & Privacy SQL Setup
-- ============================================

-- 1. ADDITIONAL STRUCTURES (TIMESTAMP FOR SYNC)
-- Assuming that 'matches' and 'scores' tables already exist. We add the control field.
ALTER TABLE matches ADD COLUMN IF NOT EXISTS local_updated_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE scores ADD COLUMN IF NOT EXISTS local_updated_at TIMESTAMP WITH TIME ZONE;

-- ============================================
-- 2. PRIVACY (DATA LEAKAGE PREVENTION)
-- ============================================
-- View designed so clients can download the snapshot without taking PII.
CREATE OR REPLACE VIEW public_tournament_snapshot AS
SELECT 
    p.id AS person_id,
    p.first_name,
    COALESCE(p.nickname, p.last_name) AS display_name,
    ast.current_elo AS current_elo,
    ast.sport_id
FROM persons p
JOIN athlete_stats ast ON p.id = ast.person_id;

-- ============================================
-- 3. ROW LEVEL SECURITY (RLS - SUPABASE)
-- ============================================
-- Enable RLS on critical tables
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;
-- RLS for elo_history will be set up when the table is created (migration 00000000000002)
-- ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- POLICY 1: SCORES (Write restricted to the referee)
CREATE POLICY "Scores insert/update allowed only for assigned referee" 
ON scores
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM matches m
        WHERE m.id = scores.match_id
        AND m.referee_id = auth.uid()
    )
);

-- POLICY 1.5: MATCHES (Staff Access Control)
CREATE POLICY "Matches refer to authorized staff" 
ON matches
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM categories c
        JOIN tournament_staff ts ON c.tournament_id = ts.tournament_id
        WHERE c.id = matches.category_id
        AND ts.user_id = matches.referee_id
    )
);

-- POLICY 2: ELO_HISTORY (Read-only for users, insert only via Trigger)
-- Moved to migration 00000000000002_add_elo_history.sql
-- CREATE POLICY "Elo history is read only for users" 
-- ON elo_history
-- FOR SELECT
-- USING (true);
-- Note: No INSERT policy is created. This blocks insertions from the RLS client.
-- Database triggers bypass RLS if they use the SECURITY DEFINER function.

-- ============================================
-- 4. CONFLICT RESOLUTION (LAST-WRITE-WINS AND TIME-TAMPERING)
-- ============================================
-- Function to avoid overwriting fresh data with obsolete client data and to block tampered clocks.
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

CREATE TRIGGER trg_matches_conflict_resolution
BEFORE UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION check_offline_sync_conflict();

CREATE TRIGGER trg_scores_conflict_resolution
BEFORE UPDATE ON scores
FOR EACH ROW EXECUTE FUNCTION check_offline_sync_conflict();

-- ============================================
-- 5. INTEGRITY TRIGGER (ELO AND WINNERS)
-- ============================================
-- Ensure critical changes (Advancing round, calculating ELO) are done server-side ('SECURITY DEFINER')
CREATE OR REPLACE FUNCTION process_match_completion()
RETURNS TRIGGER 
SECURITY DEFINER -- This ignores RLS, allowing insertion into protected tables
AS $$
BEGIN
    -- Simplified Logic: If the match transitions to FINISHED state
    IF NEW.status = 'FINISHED' AND OLD.status != 'FINISHED' THEN
        -- ELO math goes here (Server-side)
        -- INSERT INTO elo_history (...) VALUES (...)
        
        -- Move the winner to the next Bracket (Linked List)
        -- UPDATE matches SET entry_a_id = WINNER_ID WHERE id = NEW.next_match_id;
        NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_match_completion
AFTER UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION process_match_completion();

-- ============================================
-- 6. ORGANIZATIONAL AUTHORIZATION (STAFF & TOURNAMENTS)
-- ============================================
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_staff ENABLE ROW LEVEL SECURITY;

-- Only verified users can create tournaments
CREATE POLICY "Users can create tournaments" 
ON tournaments FOR INSERT 
WITH CHECK (auth.uid() IS NOT NULL);

-- Auto-assign tournament creator as ORGANIZER
CREATE OR REPLACE FUNCTION assign_tournament_creator_as_organizer()
RETURNS TRIGGER SECURITY DEFINER AS $$
BEGIN
    INSERT INTO tournament_staff (tournament_id, user_id, role)
    VALUES (NEW.id, auth.uid(), 'ORGANIZER');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tournament_created_assign_organizer
AFTER INSERT ON tournaments
FOR EACH ROW EXECUTE FUNCTION assign_tournament_creator_as_organizer();

-- Only ORGANIZERS can add or modify staff
CREATE POLICY "Only organizers can manage staff"
ON tournament_staff FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = tournament_staff.tournament_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
);

-- ============================================
-- 7. OPERATIONAL ROLLBACK (UNDO MATCH)
-- ============================================
CREATE OR REPLACE FUNCTION rollback_match(p_match_id UUID)
RETURNS VOID SECURITY DEFINER AS $$
DECLARE
    v_match matches%ROWTYPE;
BEGIN
    SELECT * INTO v_match FROM matches WHERE id = p_match_id;
    
    -- Validate that the executor is an ORGANIZER
    IF NOT EXISTS (
        SELECT 1 FROM categories c
        JOIN tournament_staff ts ON c.tournament_id = ts.tournament_id
        WHERE c.id = v_match.category_id AND ts.user_id = auth.uid() AND ts.role = 'ORGANIZER'
    ) THEN
        RAISE EXCEPTION 'Access Denied: Only ORGANIZER can rollback matches.';
    END IF;

    -- Revert state to LIVE
    UPDATE matches SET status = 'LIVE' WHERE id = p_match_id;

    -- Clear bracket of projected winner
    IF v_match.next_match_id IS NOT NULL THEN
        UPDATE matches SET entry_a_id = NULL WHERE id = v_match.next_match_id AND entry_a_id IN (v_match.entry_a_id, v_match.entry_b_id);
        UPDATE matches SET entry_b_id = NULL WHERE id = v_match.next_match_id AND entry_b_id IN (v_match.entry_a_id, v_match.entry_b_id);
    END IF;

    -- Accounting logic for ELO_HISTORY return (pseudo)
    -- INSERT INTO elo_history (match_id, previous_elo, new_elo) SELECT ..., -delta FROM elo_history WHERE match_id = p_match_id;
END;
$$ LANGUAGE plpgsql;
