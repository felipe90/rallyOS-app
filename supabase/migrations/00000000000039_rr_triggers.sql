-- Migration: 00000000000039_rr_triggers.sql
-- Triggers for Round Robin integrity validation
-- 
-- Triggers:
-- 1. trg_validate_group_member_count - Max 5 members per group
-- 2. trg_unique_person_per_tournament - One group per person per tournament
-- 3. trg_unique_seed_per_group - Unique seeds within group
-- 4. trg_update_group_status - Auto-update group status on match completion
-- 5. trg_validate_intra_group_referee - Referee must be from same group in RR
-- 6. trg_track_loser_for_referee - Store loser for next match assignment

-- ============================================
-- TRIGGER 1: Validate Group Member Count
-- ============================================

CREATE OR REPLACE FUNCTION fn_validate_group_member_count()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    max_members INTEGER := 5;
BEGIN
    -- Get current member count (excluding the one being updated/deleted)
    IF TG_OP = 'DELETE' THEN
        SELECT COUNT(*) INTO current_count
        FROM group_members
        WHERE group_id = OLD.group_id;
    ELSE
        SELECT COUNT(*) INTO current_count
        FROM group_members
        WHERE group_id = NEW.group_id
        AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
    END IF;
    
    IF current_count >= max_members AND TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'Group cannot have more than % members', max_members;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_group_member_count ON group_members;
CREATE TRIGGER trg_validate_group_member_count
BEFORE INSERT ON group_members
FOR EACH ROW EXECUTE FUNCTION fn_validate_group_member_count();

-- ============================================
-- TRIGGER 2: Unique Person Per Tournament
-- ============================================

CREATE OR REPLACE FUNCTION fn_unique_person_per_tournament()
RETURNS TRIGGER AS $$
DECLARE
    existing_group_id UUID;
    v_tournament_id UUID;
BEGIN
    -- Get tournament_id from the group
    SELECT tournament_id INTO v_tournament_id
    FROM round_robin_groups
    WHERE id = NEW.group_id;
    
    -- Find if person is already in another group of same tournament
    SELECT gm.group_id INTO existing_group_id
    FROM group_members gm
    JOIN round_robin_groups rrg ON gm.group_id = rrg.id
    WHERE gm.person_id = NEW.person_id
    AND rrg.tournament_id = v_tournament_id
    AND gm.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
    
    IF existing_group_id IS NOT NULL THEN
        RAISE EXCEPTION 'Person % is already in a group for this tournament', NEW.person_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_unique_person_per_tournament ON group_members;
CREATE TRIGGER trg_unique_person_per_tournament
BEFORE INSERT ON group_members
FOR EACH ROW EXECUTE FUNCTION fn_unique_person_per_tournament();

-- ============================================
-- TRIGGER 3: Unique Seed Per Group
-- ============================================

CREATE OR REPLACE FUNCTION fn_unique_seed_per_group()
RETURNS TRIGGER AS $$
DECLARE
    existing_seed INTEGER;
BEGIN
    SELECT seed INTO existing_seed
    FROM group_members
    WHERE group_id = NEW.group_id
    AND seed = NEW.seed
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
    
    IF existing_seed IS NOT NULL THEN
        RAISE EXCEPTION 'Seed % already exists in group %', NEW.seed, NEW.group_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_unique_seed_per_group ON group_members;
CREATE TRIGGER trg_unique_seed_per_group
BEFORE INSERT OR UPDATE ON group_members
FOR EACH ROW EXECUTE FUNCTION fn_unique_seed_per_group();

-- ============================================
-- TRIGGER 4: Update Group Status on Match Complete
-- ============================================

CREATE OR REPLACE FUNCTION fn_update_group_status_on_match_complete()
RETURNS TRIGGER AS $$
DECLARE
    v_group_id UUID;
    v_pending_matches INTEGER;
    v_group_status group_status;
BEGIN
    -- Only trigger on status change to FINISHED or WALKED_OVER
    IF OLD.status IN ('FINISHED', 'WALKED_OVER') THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status NOT IN ('FINISHED', 'WALKED_OVER') THEN
        RETURN NEW;
    END IF;
    
    -- Get group_id from match
    SELECT group_id INTO v_group_id FROM matches WHERE id = NEW.id;
    
    IF v_group_id IS NULL THEN
        RETURN NEW;  -- Not a group match, skip
    END IF;
    
    -- Count pending matches in group
    SELECT COUNT(*) INTO v_pending_matches
    FROM matches
    WHERE group_id = v_group_id
    AND status NOT IN ('FINISHED', 'WALKED_OVER', 'CANCELLED');
    
    -- Update group status
    IF v_pending_matches = 0 THEN
        UPDATE round_robin_groups
        SET status = 'COMPLETED', updated_at = NOW()
        WHERE id = v_group_id;
    ELSE
        -- Check if group is still PENDING, change to IN_PROGRESS
        SELECT status INTO v_group_status FROM round_robin_groups WHERE id = v_group_id;
        IF v_group_status = 'PENDING' THEN
            UPDATE round_robin_groups
            SET status = 'IN_PROGRESS', updated_at = NOW()
            WHERE id = v_group_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_group_status ON matches;
CREATE TRIGGER trg_update_group_status
AFTER UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION fn_update_group_status_on_match_complete();

-- ============================================
-- TRIGGER 5: Validate Intra-Group Referee
-- ============================================

CREATE OR REPLACE FUNCTION fn_validate_intra_group_referee()
RETURNS TRIGGER AS $$
DECLARE
    v_match_group_id UUID;
    v_match_entry_a UUID;
    v_match_entry_b UUID;
    v_referee_person_id UUID;
    v_match_phase match_phase;
BEGIN
    -- Get match info
    SELECT 
        m.group_id,
        m.entry_a_id,
        m.entry_b_id,
        m.phase
    INTO v_match_group_id, v_match_entry_a, v_match_entry_b, v_match_phase
    FROM matches m
    WHERE m.id = NEW.match_id;
    
    -- If no group (bracket match), skip validation
    IF v_match_group_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- If not ROUND_ROBIN phase, skip (KO allows any referee)
    IF v_match_phase != 'ROUND_ROBIN' THEN
        RETURN NEW;
    END IF;
    
    -- Get referee's person_id from user_id
    SELECT p.id INTO v_referee_person_id
    FROM auth.users au
    JOIN persons p ON au.id = p.user_id
    WHERE au.id = NEW.user_id;
    
    -- Validate referee is in same group
    IF NOT EXISTS (
        SELECT 1 FROM group_members gm
        WHERE gm.group_id = v_match_group_id
        AND gm.person_id = v_referee_person_id
    ) THEN
        RAISE EXCEPTION 'Referee must be from the same Round Robin group';
    END IF;
    
    -- Validate referee is not playing (entry not in match)
    IF EXISTS (
        SELECT 1 FROM group_members gm
        JOIN tournament_entries te ON gm.entry_id = te.id
        WHERE gm.group_id = v_match_group_id
        AND gm.person_id = v_referee_person_id
        AND te.id IN (v_match_entry_a, v_match_entry_b)
    ) THEN
        RAISE EXCEPTION 'Referee cannot be one of the players';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_intra_group_referee ON referee_assignments;
CREATE TRIGGER trg_validate_intra_group_referee
BEFORE INSERT OR UPDATE ON referee_assignments
FOR EACH ROW EXECUTE FUNCTION fn_validate_intra_group_referee();

-- ============================================
-- TRIGGER 6: Track Loser for Referee Assignment
-- ============================================

CREATE OR REPLACE FUNCTION fn_track_loser_for_referee()
RETURNS TRIGGER AS $$
DECLARE
    v_winner_entry_id UUID;
    v_loser_entry_id UUID;
    v_loser_person_id UUID;
    v_loser_user_id UUID;
    v_next_match_id UUID;
    v_next_group_id UUID;
    v_current_group_id UUID;
BEGIN
    -- Only trigger when status changes to FINISHED
    IF OLD.status = 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status != 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    -- Get match info
    SELECT 
        entry_a_id,
        entry_b_id,
        next_match_id,
        group_id
    INTO v_winner_entry_id, v_loser_entry_id, v_next_match_id, v_current_group_id
    FROM matches
    WHERE id = NEW.id;
    
    -- Determine winner and loser from score
    IF EXISTS (SELECT 1 FROM scores WHERE match_id = NEW.id) THEN
        SELECT 
            CASE 
                WHEN points_a > points_b THEN entry_a_id
                ELSE entry_b_id
            END,
            CASE 
                WHEN points_a > points_b THEN entry_b_id
                ELSE entry_a_id
            END
        INTO v_winner_entry_id, v_loser_entry_id
        FROM matches
        WHERE id = NEW.id;
        
        -- Get loser person_id
        SELECT person_id INTO v_loser_person_id
        FROM tournament_entries
        WHERE id = v_loser_entry_id;
        
        -- Get loser user_id
        SELECT user_id INTO v_loser_user_id
        FROM persons
        WHERE id = v_loser_person_id;
        
        -- Store loser for next match if there's a next match
        IF v_loser_user_id IS NOT NULL AND v_next_match_id IS NOT NULL THEN
            -- Check if loser is in same group as next match
            SELECT group_id INTO v_next_group_id
            FROM matches
            WHERE id = v_next_match_id;
            
            -- Only store if same group (cross-group can't referee)
            IF v_next_group_id = v_current_group_id THEN
                UPDATE matches
                SET loser_assigned_referee = v_loser_user_id
                WHERE id = v_next_match_id;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_track_loser_for_referee ON matches;
CREATE TRIGGER trg_track_loser_for_referee
AFTER UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION fn_track_loser_for_referee();

-- ============================================
-- TRIGGER 7: Update updated_at timestamps
-- ============================================

CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_rrg_updated_at ON round_robin_groups;
CREATE TRIGGER trg_rrg_updated_at
BEFORE UPDATE ON round_robin_groups
FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

DROP TRIGGER IF EXISTS trg_kb_updated_at ON knockout_brackets;
CREATE TRIGGER trg_kb_updated_at
BEFORE UPDATE ON knockout_brackets
FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

-- ============================================
-- TRIGGER 8: Validate TT Score Rules
-- ============================================

CREATE OR REPLACE FUNCTION fn_validate_score_tt_rules()
RETURNS TRIGGER AS $$
DECLARE
    v_sport_id UUID;
    v_scoring_config JSONB;
    v_points_to_win INTEGER;
    v_win_by_2 BOOLEAN;
    v_deuce_at INTEGER;
BEGIN
    -- Get sport scoring config from match
    SELECT 
        t.sport_id
    INTO v_sport_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    WHERE m.id = NEW.match_id;
    
    -- Get scoring config from sports table
    SELECT scoring_config INTO v_scoring_config
    FROM sports
    WHERE id = v_sport_id;
    
    -- Extract TT-specific values
    v_points_to_win := COALESCE(
        (v_scoring_config->>'points_per_set')::INTEGER,
        11
    );
    v_win_by_2 := COALESCE(
        (v_scoring_config->>'win_by_2')::BOOLEAN,
        TRUE
    );
    v_deuce_at := COALESCE(
        (v_scoring_config->>'deuce_at')::INTEGER,
        10
    );
    
    -- Allow 0-0 as initial state
    IF NEW.points_a = 0 AND NEW.points_b = 0 THEN
        RETURN NEW;
    END IF;
    
    -- TT Validation Rules:
    -- 1. Points must be non-negative
    IF NEW.points_a < 0 OR NEW.points_b < 0 THEN
        RAISE EXCEPTION 'Points cannot be negative';
    END IF;
    
    -- 2. If both < deuce_at + 1, one must be ahead by 1
    IF NEW.points_a < v_deuce_at + 1 AND NEW.points_b < v_deuce_at + 1 THEN
        IF ABS(NEW.points_a - NEW.points_b) != 1 THEN
            RAISE EXCEPTION 'Before deuce (before %), difference must be 1 point', v_deuce_at;
        END IF;
    END IF;
    
    -- 3. If one reaches v_points_to_win (11), must win by 2
    IF (NEW.points_a >= v_points_to_win OR NEW.points_b >= v_points_to_win) THEN
        IF v_win_by_2 THEN
            IF ABS(NEW.points_a - NEW.points_b) < 2 THEN
                RAISE EXCEPTION 'Must win by 2 points in Table Tennis';
            END IF;
        END IF;
    END IF;
    
    -- 4. Extended deuce: if both >= deuce_at, continue until diff = 2
    IF NEW.points_a >= v_deuce_at AND NEW.points_b >= v_deuce_at THEN
        IF ABS(NEW.points_a - NEW.points_b) != 2 THEN
            RAISE EXCEPTION 'In deuce (10-10+), must win by 2 points';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger might already exist from previous migration
-- Let's check and create only if not exists
DROP TRIGGER IF EXISTS trg_validate_score_tt_rules ON scores;
CREATE TRIGGER trg_validate_score_tt_rules
BEFORE INSERT OR UPDATE ON scores
FOR EACH ROW EXECUTE FUNCTION fn_validate_score_tt_rules();
