-- Migration: 00000000000040_rr_rpcs.sql
-- RPC Functions for Round Robin Operations
-- 
-- RPCs:
-- 1. create_round_robin_group - Create group + members + matches
-- 2. generate_round_robin_matches - Generate RR schedule
-- 3. suggest_intra_group_referee - Get suggested referee
-- 4. assign_loser_as_referee - Auto-assign loser to next match
-- 5. calculate_group_standings - Get group classification
-- 6. add_member_to_group - Add member with validation
-- 7. generate_bracket_from_groups - Create KO bracket

-- ============================================
-- RPC 1: Create Round Robin Group
-- ============================================

CREATE OR REPLACE FUNCTION create_round_robin_group(
    p_tournament_id UUID,
    p_name TEXT,
    p_member_entry_ids UUID[],
    p_advancement_count INTEGER DEFAULT 2
)
RETURNS TABLE(
    group_id UUID,
    match_ids UUID[]
) AS $$
DECLARE
    v_group_id UUID;
    v_seed INTEGER := 1;
    v_entry_id UUID;
    v_match_id UUID;
    v_match_ids UUID[] := '{}';
    v_category_id UUID;
BEGIN
    -- Validate tournament exists and is in appropriate status
    IF NOT EXISTS (
        SELECT 1 FROM tournaments 
        WHERE id = p_tournament_id 
        AND status IN ('DRAFT', 'REGISTRATION', 'PRE_TOURNAMENT', 'CHECK_IN')
    ) THEN
        RAISE EXCEPTION 'Tournament must be in DRAFT, REGISTRATION, PRE_TOURNAMENT, or CHECK_IN status';
    END IF;
    
    -- Validate member count (read from sport config or use defaults 3-5)
    IF array_length(p_member_entry_ids, 1) < 3 THEN
        RAISE EXCEPTION 'Group must have at least 3 members';
    END IF;
    
    IF array_length(p_member_entry_ids, 1) > 5 THEN
        RAISE EXCEPTION 'Group cannot have more than 5 members (configurable in sport settings)';
    END IF;
    
    -- Validate no duplicate entries
    IF array_length(p_member_entry_ids, 1) != (SELECT COUNT(DISTINCT unnest) FROM unnest(p_member_entry_ids) AS unnest) THEN
        RAISE EXCEPTION 'Duplicate entries in member list';
    END IF;
    
    -- Get category_id from first entry
    SELECT category_id INTO v_category_id
    FROM tournament_entries
    WHERE id = p_member_entry_ids[1];
    
    -- Create group
    INSERT INTO round_robin_groups (tournament_id, name, advancement_count)
    VALUES (p_tournament_id, p_name, p_advancement_count)
    RETURNING id INTO v_group_id;
    
    -- Add members with seeding
    FOREACH v_entry_id IN ARRAY p_member_entry_ids
    LOOP
        INSERT INTO group_members (group_id, entry_id, person_id, seed)
        SELECT 
            v_group_id,
            v_entry_id,
            (SELECT person_id FROM entry_members WHERE entry_id = v_entry_id LIMIT 1),
            v_seed;
        
        v_seed := v_seed + 1;
    END LOOP;
    
    -- Generate round robin matches
    v_match_ids := generate_round_robin_matches(v_group_id);
    
    RETURN QUERY SELECT v_group_id, v_match_ids;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 2: Generate Round Robin Matches
-- ============================================

CREATE OR REPLACE FUNCTION generate_round_robin_matches(p_group_id UUID)
RETURNS UUID[] AS $$
DECLARE
    v_member_ids UUID[];
    v_match_ids UUID[] := '{}';
    v_i INTEGER;
    v_j INTEGER;
    v_entry_a UUID;
    v_entry_b UUID;
    v_match_id UUID;
    v_round INTEGER := 1;
    v_match_count INTEGER := 0;
    v_category_id UUID;
BEGIN
    -- Get category_id from group
    SELECT c.id INTO v_category_id
    FROM round_robin_groups rrg
    JOIN tournament_entries te ON te.category_id = c.id
    JOIN group_members gm ON gm.entry_id = te.id
    WHERE gm.group_id = p_group_id
    LIMIT 1;
    
    -- Get all member entry_ids ordered by seed
    SELECT ARRAY_AGG(entry_id ORDER BY seed)
    INTO v_member_ids
    FROM group_members
    WHERE group_id = p_group_id;
    
    -- Generate matches using round-robin circular algorithm
    FOR v_i IN 1..array_length(v_member_ids, 1) LOOP
        FOR v_j IN (v_i + 1)..array_length(v_member_ids, 1) LOOP
            v_entry_a := v_member_ids[v_i];
            v_entry_b := v_member_ids[v_j];
            
            v_match_count := v_match_count + 1;
            
            -- Calculate round (2 matches per round for better scheduling)
            v_round := ceil(v_match_count::DECIMAL / 2)::INTEGER;
            
            INSERT INTO matches (
                group_id,
                category_id,
                entry_a_id,
                entry_b_id,
                round_number,
                status,
                phase
            )
            VALUES (
                p_group_id,
                v_category_id,
                v_entry_a,
                v_entry_b,
                v_round,
                'SCHEDULED',
                'ROUND_ROBIN'
            )
            RETURNING id INTO v_match_id;
            
            v_match_ids := array_append(v_match_ids, v_match_id);
        END LOOP;
    END LOOP;
    
    -- Link matches in sequence (next_match_of_winner)
    FOR v_i IN 1..array_length(v_match_ids, 1) - 1 LOOP
        UPDATE matches
        SET next_match_id = v_match_ids[v_i + 1]
        WHERE id = v_match_ids[v_i];
    END LOOP;
    
    RETURN v_match_ids;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 3: Suggest Intra-Group Referee
-- ============================================

CREATE OR REPLACE FUNCTION suggest_intra_group_referee(p_match_id UUID)
RETURNS TABLE(
    user_id UUID,
    assignment_type TEXT,
    reason TEXT
) AS $$
DECLARE
    v_group_id UUID;
    v_entry_a_id UUID;
    v_entry_b_id UUID;
    v_loser_user_id UUID;
    v_bye_member_id UUID;
BEGIN
    -- Get match info
    SELECT group_id, entry_a_id, entry_b_id, loser_assigned_referee
    INTO v_group_id, v_entry_a_id, v_entry_b_id, v_loser_user_id
    FROM matches
    WHERE id = p_match_id;
    
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Match is not part of a Round Robin group';
    END IF;
    
    -- Priority 1: Loser of previous match (BR-LOSER-001)
    IF v_loser_user_id IS NOT NULL THEN
        -- Verify loser is in same group and not playing
        IF EXISTS (
            SELECT 1 FROM group_members gm
            JOIN tournament_entries te ON gm.entry_id = te.id
            JOIN persons p ON te.person_id = p.id
            WHERE gm.group_id = v_group_id
            AND p.user_id = v_loser_user_id
            AND gm.entry_id NOT IN (v_entry_a_id, v_entry_b_id)
            AND gm.status = 'ACTIVE'
        ) THEN
            RETURN QUERY SELECT v_loser_user_id, 'LOSER_ASSIGNED'::TEXT, 
                'Loser of previous match has priority'::TEXT;
            RETURN;
        END IF;
    END IF;
    
    -- Priority 2: Member with BYE in current round
    SELECT au.id INTO v_bye_member_id
    FROM group_members gm
    JOIN tournament_entries te ON gm.entry_id = te.id
    JOIN persons p ON te.person_id = p.id
    JOIN auth.users au ON p.user_id = au.id
    WHERE gm.group_id = v_group_id
    AND gm.round_bye = (SELECT round_number FROM matches WHERE id = p_match_id)
    AND gm.entry_id NOT IN (v_entry_a_id, v_entry_b_id)
    AND gm.status = 'ACTIVE'
    AND gm.check_in_at IS NOT NULL
    LIMIT 1;
    
    IF v_bye_member_id IS NOT NULL THEN
        RETURN QUERY SELECT v_bye_member_id, 'AUTOMATIC'::TEXT, 
            'Member has BYE this round'::TEXT;
        RETURN;
    END IF;
    
    -- Priority 3: Member with fewest referee assignments (round-robin)
    RETURN QUERY
    SELECT 
        au.id,
        'AUTOMATIC'::TEXT,
        'Least matches refereed'::TEXT
    FROM group_members gm
    JOIN tournament_entries te ON gm.entry_id = te.id
    JOIN persons p ON te.person_id = p.id
    JOIN auth.users au ON p.user_id = au.id
    LEFT JOIN referee_assignments ra ON au.id = ra.user_id
    WHERE gm.group_id = v_group_id
    AND gm.entry_id NOT IN (v_entry_a_id, v_entry_b_id)
    AND gm.status = 'ACTIVE'
    AND gm.check_in_at IS NOT NULL
    GROUP BY au.id
    ORDER BY COUNT(ra.id) ASC, RANDOM()
    LIMIT 1;
    
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 4: Assign Loser as Referee
-- ============================================

CREATE OR REPLACE FUNCTION assign_loser_as_referee(p_match_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_winner_entry_id UUID;
    v_loser_entry_id UUID;
    v_loser_person_id UUID;
    v_loser_user_id UUID;
    v_next_match_id UUID;
    v_next_group_id UUID;
    v_current_group_id UUID;
BEGIN
    -- Get match info
    SELECT 
        entry_a_id,
        entry_b_id,
        next_match_id,
        group_id
    INTO v_winner_entry_id, v_loser_entry_id, v_next_match_id, v_current_group_id
    FROM matches
    WHERE id = p_match_id;
    
    IF v_next_match_id IS NULL THEN
        RETURN FALSE;  -- No next match (e.g., final)
    END IF;
    
    -- Get next match's group
    SELECT group_id INTO v_next_group_id FROM matches WHERE id = v_next_match_id;
    
    -- Determine winner/loser from score
    IF EXISTS (SELECT 1 FROM scores WHERE match_id = p_match_id) THEN
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
        WHERE id = p_match_id;
    END IF;
    
    -- Get loser user_id
    SELECT p.user_id INTO v_loser_user_id
    FROM tournament_entries te
    JOIN persons p ON te.person_id = p.id
    WHERE te.id = v_loser_entry_id;
    
    IF v_loser_user_id IS NULL THEN
        RETURN FALSE;  -- Shadow profile, cannot be referee
    END IF;
    
    -- BR-LOSER-002: Cross-group check
    IF v_next_group_id != v_current_group_id THEN
        -- Cannot assign cross-group, clear stored loser and return FALSE
        UPDATE matches SET loser_assigned_referee = NULL WHERE id = v_next_match_id;
        RETURN FALSE;
    END IF;
    
    -- Create/update referee assignment
    INSERT INTO referee_assignments (
        match_id,
        user_id,
        assignment_type,
        is_suggested,
        is_confirmed
    )
    VALUES (
        v_next_match_id,
        v_loser_user_id,
        'LOSER_ASSIGNED',
        TRUE,
        FALSE
    )
    ON CONFLICT (match_id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        assignment_type = 'LOSER_ASSIGNED',
        is_suggested = TRUE,
        is_confirmed = FALSE;
    
    -- Clear the stored loser reference
    UPDATE matches SET loser_assigned_referee = NULL WHERE id = v_next_match_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 5: Calculate Group Standings
-- ============================================

CREATE OR REPLACE FUNCTION calculate_group_standings(p_group_id UUID)
RETURNS TABLE(
    rank INTEGER,
    member_id UUID,
    person_id UUID,
    matches_played INTEGER,
    wins INTEGER,
    losses INTEGER,
    points_for INTEGER,
    points_against INTEGER,
    point_diff INTEGER,
    total_points INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH member_stats AS (
        SELECT 
            gm.id as member_id,
            gm.person_id,
            gm.entry_id,
            gm.seed,
            COUNT(DISTINCT m.id) as matches_played,
            SUM(CASE 
                WHEN (m.entry_a_id = gm.entry_id AND s.points_a > s.points_b)
                  OR (m.entry_b_id = gm.entry_id AND s.points_b > s.points_a)
                THEN 1 ELSE 0 
            END)::INTEGER as wins,
            SUM(CASE 
                WHEN (m.entry_a_id = gm.entry_id AND s.points_a < s.points_b)
                  OR (m.entry_b_id = gm.entry_id AND s.points_b < s.points_a)
                THEN 1 ELSE 0 
            END)::INTEGER as losses,
            -- Points for: sum of points scored
            COALESCE(SUM(
                CASE WHEN m.entry_a_id = gm.entry_id THEN s.points_a ELSE s.points_b END
            ), 0)::INTEGER as points_for,
            -- Points against: sum of points conceded
            COALESCE(SUM(
                CASE WHEN m.entry_a_id = gm.entry_id THEN s.points_b ELSE s.points_a END
            ), 0)::INTEGER as points_against
        FROM group_members gm
        LEFT JOIN matches m ON 
            (m.entry_a_id = gm.entry_id OR m.entry_b_id = gm.entry_id)
            AND m.group_id = p_group_id
            AND m.status = 'FINISHED'
        LEFT JOIN scores s ON m.id = s.match_id
        WHERE gm.group_id = p_group_id
        GROUP BY gm.id, gm.person_id, gm.entry_id, gm.seed
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY 
            ms.wins * 3 DESC,  -- 3 points per win
            (ms.points_for - ms.points_against) DESC,  -- Point diff
            ms.points_for DESC,  -- Points for
            ms.points_against ASC,  -- Points against
            RANDOM()  -- Tiebreaker
        )::INTEGER as rank,
        ms.member_id,
        ms.person_id,
        ms.matches_played,
        ms.wins,
        ms.losses,
        ms.points_for,
        ms.points_against,
        (ms.points_for - ms.points_against)::INTEGER as point_diff,
        (ms.wins * 3)::INTEGER as total_points
    FROM member_stats ms;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 6: Add Member to Group
-- ============================================

CREATE OR REPLACE FUNCTION add_member_to_group(
    p_group_id UUID,
    p_entry_id UUID,
    p_seed INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_member_id UUID;
    v_current_count INTEGER;
    v_max_seed INTEGER;
    v_person_id UUID;
BEGIN
    -- Check group exists and is editable
    IF NOT EXISTS (
        SELECT 1 FROM round_robin_groups 
        WHERE id = p_group_id 
        AND status = 'PENDING'
    ) THEN
        RAISE EXCEPTION 'Can only add members to PENDING groups';
    END IF;
    
    -- Check current member count
    SELECT COUNT(*) INTO v_current_count
    FROM group_members
    WHERE group_id = p_group_id;
    
    IF v_current_count >= 5 THEN
        RAISE EXCEPTION 'Group already has maximum 5 members';
    END IF;
    
    -- Get person_id from entry
    SELECT person_id INTO v_person_id
    FROM tournament_entries
    WHERE id = p_entry_id;
    
    -- Check person not already in another group of same tournament
    IF EXISTS (
        SELECT 1 FROM group_members gm
        JOIN round_robin_groups rrg ON gm.group_id = rrg.id
        WHERE gm.person_id = v_person_id
        AND rrg.tournament_id = (SELECT tournament_id FROM round_robin_groups WHERE id = p_group_id)
    ) THEN
        RAISE EXCEPTION 'Person is already in another group for this tournament';
    END IF;
    
    -- If no seed provided, assign next available
    IF p_seed IS NULL THEN
        SELECT COALESCE(MAX(seed), 0) + 1 INTO v_max_seed
        FROM group_members
        WHERE group_id = p_group_id;
        p_seed := v_max_seed;
    END IF;
    
    -- Check seed not already taken
    IF EXISTS (
        SELECT 1 FROM group_members 
        WHERE group_id = p_group_id AND seed = p_seed
    ) THEN
        RAISE EXCEPTION 'Seed % already taken in this group', p_seed;
    END IF;
    
    INSERT INTO group_members (group_id, entry_id, person_id, seed)
    VALUES (p_group_id, p_entry_id, v_person_id, p_seed)
    RETURNING id INTO v_member_id;
    
    RETURN v_member_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 7: Generate Bracket from Groups
-- ============================================

CREATE OR REPLACE FUNCTION generate_bracket_from_groups(p_tournament_id UUID)
RETURNS UUID AS $$
DECLARE
    v_bracket_id UUID;
    v_group_ids UUID[];
    v_slot_position INTEGER := 1;
    v_round INTEGER := 1;
    v_slots_per_round INTEGER;
    v_total_slots INTEGER;
    v_i INTEGER;
    v_group_count INTEGER;
BEGIN
    -- Validate all groups are COMPLETED
    IF EXISTS (
        SELECT 1 FROM round_robin_groups
        WHERE tournament_id = p_tournament_id
        AND status != 'COMPLETED'
    ) THEN
        RAISE EXCEPTION 'All groups must be COMPLETED before generating bracket';
    END IF;
    
    -- Check no bracket exists
    IF EXISTS (
        SELECT 1 FROM knockout_brackets
        WHERE tournament_id = p_tournament_id
    ) THEN
        RAISE EXCEPTION 'Bracket already exists for this tournament';
    END IF;
    
    -- Create bracket
    INSERT INTO knockout_brackets (tournament_id)
    VALUES (p_tournament_id)
    RETURNING id INTO v_bracket_id;
    
    -- Get all groups ordered by name
    SELECT ARRAY_AGG(id ORDER BY name) INTO v_group_ids
    FROM round_robin_groups
    WHERE tournament_id = p_tournament_id;
    
    v_group_count := array_length(v_group_ids, 1);
    
    -- Calculate total qualifiers
    SELECT 
        SUM(advancement_count)::INTEGER INTO v_total_slots
    FROM round_robin_groups
    WHERE tournament_id = p_tournament_id;
    
    -- Round up to power of 2
    v_total_slots := pow(2, ceil(log(2, v_total_slots::numeric)))::INTEGER;
    
    -- First round slots = v_total_slots
    v_slots_per_round := v_total_slots;
    v_round := 1;
    
    -- Create first round slots (qualifiers from groups)
    FOR v_i IN 1..v_total_slots LOOP
        DECLARE
            v_group_idx INTEGER := ((v_i - 1) / (v_total_slots / v_group_count)) + 1;
            v_position_in_group INTEGER := ((v_i - 1) % (v_total_slots / v_group_count)) + 1;
            v_entry_id UUID;
            v_seed_source TEXT;
            v_round_name TEXT;
        BEGIN
            -- Get entry_id based on position in group
            SELECT 
                gm.entry_id,
                rrg.name || '_' || gm.seed
            INTO v_entry_id, v_seed_source
            FROM round_robin_groups rrg
            JOIN group_members gm ON gm.group_id = rrg.id
            WHERE rrg.id = v_group_ids[GREATEST(1, LEAST(v_group_idx, v_group_count))]
            AND gm.seed = v_position_in_group;
            
            -- Determine round name
            IF v_slots_per_round = 2 THEN
                v_round_name := 'Final';
            ELSIF v_slots_per_round = 4 THEN
                v_round_name := 'Semifinals';
            ELSIF v_slots_per_round >= 8 THEN
                v_round_name := 'Quarterfinals';
            ELSE
                v_round_name := 'Round ' || v_round;
            END IF;
            
            INSERT INTO bracket_slots (
                bracket_id,
                position,
                round,
                round_name,
                entry_id,
                seed_source
            )
            VALUES (
                v_bracket_id,
                v_slot_position,
                v_round,
                v_round_name,
                v_entry_id,
                v_seed_source
            );
            
            v_slot_position := v_slot_position + 1;
        END;
    END LOOP;
    
    -- Create subsequent rounds (empty slots)
    WHILE v_slots_per_round > 1 LOOP
        v_slots_per_round := v_slots_per_round / 2;
        v_round := v_round + 1;
        
        FOR v_i IN 1..v_slots_per_round LOOP
            INSERT INTO bracket_slots (
                bracket_id,
                position,
                round,
                round_name,
                entry_id
            )
            VALUES (
                v_bracket_id,
                v_slot_position,
                v_round,
                CASE 
                    WHEN v_slots_per_round = 1 THEN 'Final'
                    WHEN v_slots_per_round = 2 THEN 'Semifinals'
                    ELSE 'Round ' || v_round
                END,
                NULL
            );
            
            v_slot_position := v_slot_position + 1;
        END LOOP;
    END LOOP;
    
    RETURN v_bracket_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RPC 8: Get Available Referees for Match
-- ============================================

CREATE OR REPLACE FUNCTION get_available_referees(p_match_id UUID)
RETURNS TABLE(
    user_id UUID,
    person_id UUID,
    display_name TEXT,
    matches_refereed INTEGER,
    is_available BOOLEAN,
    reason_unavailable TEXT
) AS $$
DECLARE
    v_group_id UUID;
    v_entry_a_id UUID;
    v_entry_b_id UUID;
BEGIN
    -- Get match info
    SELECT group_id, entry_a_id, entry_b_id
    INTO v_group_id, v_entry_a_id, v_entry_b_id
    FROM matches
    WHERE id = p_match_id;
    
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Match is not part of a Round Robin group';
    END IF;
    
    RETURN QUERY
    WITH group_players AS (
        SELECT 
            gm.person_id,
            gm.entry_id,
            gm.seed,
            gm.status,
            gm.check_in_at
        FROM group_members gm
        WHERE gm.group_id = v_group_id
    ),
    player_users AS (
        SELECT 
            p.id as person_id,
            au.id as user_id,
            p.first_name || ' ' || COALESCE(p.last_name, '') as display_name,
            gp.entry_id,
            gp.seed,
            gp.status,
            gp.check_in_at,
            COALESCE(ast.matches_refereed, 0) as matches_refereed
        FROM group_players gp
        JOIN persons p ON gp.person_id = p.id
        JOIN auth.users au ON p.user_id = au.id
        LEFT JOIN athlete_stats ast ON p.id = ast.person_id
        WHERE p.user_id IS NOT NULL  -- Must have user account
    )
    SELECT 
        pu.user_id,
        pu.person_id,
        pu.display_name,
        pu.matches_refereed,
        CASE 
            WHEN pu.entry_id IN (v_entry_a_id, v_entry_b_id) THEN FALSE
            WHEN pu.status != 'ACTIVE' THEN FALSE
            WHEN pu.check_in_at IS NULL THEN FALSE
            ELSE TRUE
        END as is_available,
        CASE 
            WHEN pu.entry_id IN (v_entry_a_id, v_entry_b_id) THEN 'Playing in this match'
            WHEN pu.status != 'ACTIVE' THEN 'Not active in group'
            WHEN pu.check_in_at IS NULL THEN 'Not checked in'
            ELSE NULL
        END as reason_unavailable
    FROM player_users pu
    ORDER BY 
        CASE WHEN is_available THEN 0 ELSE 1 END,
        pu.matches_refereed ASC,
        RANDOM();
    
END;
$$ LANGUAGE plpgsql;
