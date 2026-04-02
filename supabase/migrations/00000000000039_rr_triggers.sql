-- Migration: 00000000000039_rr_triggers.sql
-- Triggers for Round Robin integrity validation (SPORT-AGNOSTIC)
-- 
-- IMPORTANT: All rules are read from sports.scoring_config JSONB
-- Configuration path: scoring_config->'tournament_format'
-- 
-- This ensures RallyOS is sport-agnostic - rules come from sport config
-- not hardcoded assumptions.

-- ============================================
-- TRIGGER 1: Validate Group Member Count (Configurable)
-- ============================================
-- Reads max members from sports.scoring_config->tournament_format->group_size->max
-- Default: 5 if not configured

CREATE OR REPLACE FUNCTION fn_validate_group_member_count()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    max_members INTEGER;
    v_sport_id UUID;
    v_scoring_config JSONB;
BEGIN
    -- Get sport config for this tournament
    SELECT t.sport_id, s.scoring_config
    INTO v_sport_id, v_scoring_config
    FROM round_robin_groups rrg
    JOIN tournaments t ON rrg.tournament_id = t.id
    JOIN sports s ON t.sport_id = s.id
    WHERE rrg.id = NEW.group_id;
    
    -- Read max from config, default to 5 if not set
    max_members := COALESCE(
        (v_scoring_config->'tournament_format'->'group_size'->>'max')::INTEGER,
        5
    );
    
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
        RAISE EXCEPTION 'Group cannot have more than % members (configured in sport)', max_members;
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
-- Sport-agnostic: applies to all sports with groups

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
-- Sport-agnostic: applies to all sports with groups

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
-- Sport-agnostic: applies to all sports with groups

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
-- TRIGGER 5: Validate Referee Based on referee_mode
-- ============================================
-- Sport-agnostic: Only enforces intra-group rule if referee_mode = 'INTRA_GROUP'
-- Otherwise skips validation (allows external refs, rotating refs, etc.)

CREATE OR REPLACE FUNCTION fn_validate_referee_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_match_group_id UUID;
    v_match_entry_a UUID;
    v_match_entry_b UUID;
    v_referee_person_id UUID;
    v_match_phase match_phase;
    v_referee_mode TEXT;
    v_sport_id UUID;
    v_scoring_config JSONB;
BEGIN
    -- Get match info
    SELECT 
        m.group_id,
        m.entry_a_id,
        m.entry_b_id,
        m.phase,
        t.sport_id
    INTO v_match_group_id, v_match_entry_a, v_match_entry_b, v_match_phase, v_sport_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    WHERE m.id = NEW.match_id;
    
    -- Get referee_mode from sport config
    SELECT scoring_config->'tournament_format'->>'referee_mode'
    INTO v_referee_mode
    FROM sports
    WHERE id = v_sport_id;
    
    -- Get scoring config for loser_referees_winner check
    SELECT scoring_config INTO v_scoring_config FROM sports WHERE id = v_sport_id;
    
    -- If no group (bracket match), skip validation
    IF v_match_group_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- If not ROUND_ROBIN phase, skip (KO allows different referee rules)
    IF v_match_phase != 'ROUND_ROBIN' THEN
        RETURN NEW;
    END IF;
    
    -- IMPORTANT: Only enforce intra-group rule if referee_mode = 'INTRA_GROUP'
    -- For other modes (NONE, EXTERNAL, ROTATING), skip this validation
    IF v_referee_mode != 'INTRA_GROUP' THEN
        RETURN NEW;  -- Skip validation for non-intra-group modes
    END IF;
    
    -- Get referee's person_id from user_id
    SELECT p.id INTO v_referee_person_id
    FROM auth.users au
    JOIN persons p ON au.id = p.user_id
    WHERE au.id = NEW.user_id;
    
    IF v_referee_person_id IS NULL THEN
        RAISE EXCEPTION 'Referee must have a user account';
    END IF;
    
    -- Validate referee is in same group
    IF NOT EXISTS (
        SELECT 1 FROM group_members gm
        WHERE gm.group_id = v_match_group_id
        AND gm.person_id = v_referee_person_id
    ) THEN
        RAISE EXCEPTION 'Referee must be from the same group (referee_mode=INTRA_GROUP)';
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

DROP TRIGGER IF EXISTS trg_validate_referee_assignment ON referee_assignments;
CREATE TRIGGER trg_validate_referee_assignment
BEFORE INSERT OR UPDATE ON referee_assignments
FOR EACH ROW EXECUTE FUNCTION fn_validate_referee_assignment();

-- ============================================
-- TRIGGER 6: Track Loser for Referee Assignment
-- ============================================
-- Sport-agnostic: Only tracks if loser_referees_winner = true in config
-- Only applies when referee_mode = 'INTRA_GROUP'

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
    v_loser_referees_winner BOOLEAN;
    v_referee_mode TEXT;
    v_sport_id UUID;
BEGIN
    -- Only trigger when status changes to FINISHED
    IF OLD.status = 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status != 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    -- Get sport config to check loser_referees_winner and referee_mode
    SELECT 
        t.sport_id,
        m.group_id,
        m.entry_a_id,
        m.entry_b_id,
        m.next_match_id
    INTO v_sport_id, v_current_group_id, v_winner_entry_id, v_loser_entry_id, v_next_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    WHERE m.id = NEW.id;
    
    -- Check if loser_referees_winner is enabled for this sport
    SELECT 
        (scoring_config->'tournament_format'->>'loser_referees_winner')::BOOLEAN,
        scoring_config->'tournament_format'->>'referee_mode'
    INTO v_loser_referees_winner, v_referee_mode
    FROM sports
    WHERE id = v_sport_id;
    
    -- IMPORTANT: Only track if loser_referees_winner = true AND referee_mode = 'INTRA_GROUP'
    IF v_loser_referees_winner != TRUE OR v_referee_mode != 'INTRA_GROUP' THEN
        RETURN NEW;  -- Skip for sports that don't use this rule
    END IF;
    
    -- Get next match's group
    SELECT group_id INTO v_next_group_id FROM matches WHERE id = v_next_match_id;
    
    -- Determine winner/loser from score
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
    END IF;
    
    -- Get loser user_id
    SELECT p.user_id INTO v_loser_user_id
    FROM tournament_entries te
    JOIN persons p ON te.person_id = p.id
    WHERE te.id = v_loser_entry_id;
    
    IF v_loser_user_id IS NULL THEN
        RETURN NEW;  -- Shadow profile, cannot be referee
    END IF;
    
    -- Store loser for next match if there's a next match
    -- Only if same group (cross-group can't referee in INTRA_GROUP mode)
    IF v_loser_user_id IS NOT NULL AND v_next_match_id IS NOT NULL THEN
        IF v_next_group_id = v_current_group_id THEN
            UPDATE matches
            SET loser_assigned_referee = v_loser_user_id
            WHERE id = v_next_match_id;
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
-- TRIGGER 8: Validate Score Rules (Sport-Agnostic)
-- ============================================
-- Reads validation rules from sports.scoring_config JSONB
-- NOT hardcoded to Table Tennis

CREATE OR REPLACE FUNCTION fn_validate_score_rules()
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
    
    -- Extract validation values from config (sport-specific)
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
    
    -- Generic validation rules (read from config):
    -- 1. Points must be non-negative
    IF NEW.points_a < 0 OR NEW.points_b < 0 THEN
        RAISE EXCEPTION 'Points cannot be negative';
    END IF;
    
    -- 2. If both < deuce_at + 1, one must be ahead by 1
    IF NEW.points_a < v_deuce_at + 1 AND NEW.points_b < v_deuce_at + 1 THEN
        IF ABS(NEW.points_a - NEW.points_b) != 1 THEN
            RAISE EXCEPTION 'Before deuce (%), difference must be 1 point', v_deuce_at;
        END IF;
    END IF;
    
    -- 3. If one reaches v_points_to_win, must win by 2 (if win_by_2 is true)
    IF (NEW.points_a >= v_points_to_win OR NEW.points_b >= v_points_to_win) THEN
        IF v_win_by_2 THEN
            IF ABS(NEW.points_a - NEW.points_b) < 2 THEN
                RAISE EXCEPTION 'Must win by % points', v_points_to_win - (v_points_to_win - 2);
            END IF;
        END IF;
    END IF;
    
    -- 4. Extended deuce: if both >= deuce_at, continue until diff = 2
    IF NEW.points_a >= v_deuce_at AND NEW.points_b >= v_deuce_at THEN
        IF ABS(NEW.points_a - NEW.points_b) != 2 THEN
            RAISE EXCEPTION 'In deuce (%), must win by 2 points', v_deuce_at;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remove old TT-specific trigger if exists, create generic one
DROP TRIGGER IF EXISTS trg_validate_score_tt_rules ON scores;
DROP TRIGGER IF EXISTS trg_validate_score ON scores;
CREATE TRIGGER trg_validate_score
BEFORE INSERT OR UPDATE ON scores
FOR EACH ROW EXECUTE FUNCTION fn_validate_score_rules();
