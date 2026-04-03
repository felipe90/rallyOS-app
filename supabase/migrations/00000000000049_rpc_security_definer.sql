-- ============================================================
-- RALLYOS: Add SECURITY DEFINER to RPCs
-- Migration: 00000000000049_rpc_security_definer.sql
-- ============================================================
-- Purpose: Add SECURITY DEFINER to all critical RPCs that need
-- to bypass RLS for internal operations or be called from triggers.
--
-- SECURITY DEFINER Pattern:
-- - Runs with function owner's privileges (bypasses RLS)
-- - SET search_path prevents search_path injection attacks
-- - Explicit authorization checks are still required
-- ============================================================

SET search_path TO extensions, public;

-- ─────────────────────────────────────────────────────────
-- Helper: Get function definition (placeholder - will be updated per function)
-- ─────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────
-- 1. create_round_robin_group
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_round_robin_group(
    p_tournament_id UUID,
    p_name TEXT,
    p_member_entry_ids UUID[],
    p_advancement_count INTEGER DEFAULT 2
)
RETURNS TABLE(group_id UUID, match_ids UUID[])
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_group_id UUID;
    v_seed INTEGER := 1;
    v_entry_id UUID;
    v_match_id UUID;
    v_match_ids UUID[] := '{}';
    v_category_id UUID;
BEGIN
    -- Authorization: Check if user is an organizer
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = p_tournament_id
        AND user_id = auth.uid()
        AND role = 'ORGANIZER'
        AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can create groups';
    END IF;

    -- Validate tournament exists and is in appropriate status
    IF NOT EXISTS (
        SELECT 1 FROM tournaments
        WHERE id = p_tournament_id
        AND status IN ('DRAFT', 'REGISTRATION', 'PRE_TOURNAMENT', 'CHECK_IN')
    ) THEN
        RAISE EXCEPTION 'Tournament must be in DRAFT, REGISTRATION, PRE_TOURNAMENT, or CHECK_IN status';
    END IF;

    -- Validate member count
    IF array_length(p_member_entry_ids, 1) < 3 THEN
        RAISE EXCEPTION 'Group must have at least 3 members';
    END IF;

    IF array_length(p_member_entry_ids, 1) > 5 THEN
        RAISE EXCEPTION 'Group cannot have more than 5 members';
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
$$;

-- ─────────────────────────────────────────────────────────
-- 2. generate_round_robin_matches
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_round_robin_matches(p_group_id UUID)
RETURNS UUID[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_match_ids UUID[] := '{}';
    v_match_id UUID;
    v_member_count INTEGER;
    v_entry_ids UUID[];
    v_i INTEGER;
    v_j INTEGER;
    v_round INTEGER := 1;
BEGIN
    -- Get member count
    SELECT COUNT(*) INTO v_member_count
    FROM group_members
    WHERE group_id = p_group_id;

    IF v_member_count < 3 THEN
        RAISE EXCEPTION 'Group must have at least 3 members';
    END IF;

    -- Get entry IDs ordered by seed
    SELECT ARRAY_AGG(entry_id ORDER BY seed)
    INTO v_entry_ids
    FROM group_members
    WHERE group_id = p_group_id;

    -- Generate matches using round-robin algorithm
    v_i := 1;
    WHILE v_i <= v_member_count LOOP
        v_j := v_i + 1;
        WHILE v_j <= v_member_count LOOP
            -- Create match
            INSERT INTO matches (
                group_id,
                category_id,
                entry_a_id,
                entry_b_id,
                status,
                round_number,
                round_name,
                phase
            )
            SELECT
                p_group_id,
                (SELECT category_id FROM tournament_entries WHERE id = v_entry_ids[v_i]),
                v_entry_ids[v_i],
                v_entry_ids[v_j],
                'SCHEDULED',
                v_round,
                'Round ' || v_round,
                'ROUND_ROBIN'
            RETURNING id INTO v_match_id;

            v_match_ids := array_append(v_match_ids, v_match_id);

            v_j := v_j + 1;
        END LOOP;

        v_i := v_i + 1;
        v_round := v_round + 1;
    END LOOP;

    RETURN v_match_ids;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 3. offer_third_place
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION offer_third_place(p_match_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
BEGIN
    -- Check authorization (organizer of the match's tournament)
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        JOIN matches m ON m.category_id = c.id
        WHERE m.id = p_match_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can offer third place';
    END IF;

    -- Verify match is finished
    IF NOT EXISTS (
        SELECT 1 FROM matches
        WHERE id = p_match_id AND status = 'FINISHED'
    ) THEN
        RAISE EXCEPTION 'Match must be finished to offer third place';
    END IF;

    -- Set third_place_pending flag
    UPDATE matches
    SET third_place_pending = TRUE, updated_at = NOW()
    WHERE id = p_match_id;

    RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 4. accept_third_place
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION accept_third_place(p_match_id UUID, p_accepted BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
BEGIN
    -- Check authorization (player in the match)
    IF NOT EXISTS (
        SELECT 1 FROM matches m
        JOIN tournament_entries e_a ON e_a.id = m.entry_a_id
        JOIN tournament_entries e_b ON e_b.id = m.entry_b_id
        JOIN entry_members em_a ON em_a.entry_id = e_a.id
        JOIN entry_members em_b ON em_b.entry_id = e_b.id
        JOIN persons p ON p.id IN (em_a.person_id, em_b.person_id)
        WHERE m.id = p_match_id
        AND p.user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Only match participants can accept third place';
    END IF;

    -- Update acceptance flag
    UPDATE matches
    SET third_place_accepted = p_accepted, updated_at = NOW()
    WHERE id = p_match_id;

    RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 5. create_third_place_match
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_third_place_match(p_semi_a UUID, p_semi_b UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_match_id UUID;
    v_category_id UUID;
BEGIN
    -- Check authorization (organizer)
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        JOIN matches m ON m.category_id = c.id
        WHERE m.id IN (p_semi_a, p_semi_b)
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can create third place match';
    END IF;

    -- Verify both semis accepted third place
    IF NOT EXISTS (
        SELECT 1 FROM matches
        WHERE id = p_semi_a AND third_place_accepted = TRUE
    ) OR NOT EXISTS (
        SELECT 1 FROM matches
        WHERE id = p_semi_b AND third_place_accepted = TRUE
    ) THEN
        RAISE EXCEPTION 'Both semifinal losers must accept third place match';
    END IF;

    -- Get category_id
    SELECT category_id INTO v_category_id
    FROM matches WHERE id = p_semi_a;

    -- Create third place match
    INSERT INTO matches (
        category_id,
        entry_a_id,
        entry_b_id,
        status,
        round_name,
        phase,
        third_place_pending
    )
    SELECT
        v_category_id,
        get_match_loser(p_semi_a),
        get_match_loser(p_semi_b),
        'SCHEDULED',
        'Third Place',
        'THIRD_PLACE',
        FALSE
    RETURNING id INTO v_match_id;

    RETURN v_match_id;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 6. get_match_loser
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_match_loser(p_match_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path TO extensions, public
AS $$
DECLARE
    v_loser_id UUID;
BEGIN
    -- Get the loser entry_id from scores
    SELECT 
        CASE 
            WHEN s.points_a > s.points_b THEN m.entry_b_id
            ELSE m.entry_a_id
        END
    INTO v_loser_id
    FROM matches m
    JOIN scores s ON s.match_id = m.id
    WHERE m.id = p_match_id;

    RETURN v_loser_id;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 7. assign_staff
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION assign_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT,
    p_direct BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
BEGIN
    -- Check authorization (organizer)
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = p_tournament_id
        AND user_id = auth.uid()
        AND role = 'ORGANIZER'
        AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can assign staff';
    END IF;

    -- Insert or update staff record
    INSERT INTO tournament_staff (tournament_id, user_id, role, status, invite_mode, invited_by)
    VALUES (p_tournament_id, p_user_id, p_role, 'ACTIVE', p_direct, auth.uid())
    ON CONFLICT (tournament_id, user_id)
    DO UPDATE SET 
        role = EXCLUDED.role,
        status = 'ACTIVE',
        invite_mode = EXCLUDED.invite_mode;

    RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 8. invite_staff
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION invite_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
BEGIN
    RETURN assign_staff(p_tournament_id, p_user_id, p_role, TRUE);
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 9. generate_referee_suggestions
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_referee_suggestions(p_category_id UUID)
RETURNS TABLE(match_id UUID, user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_match RECORD;
    v_available_refs UUID[];
    v_ref_idx INTEGER := 0;
BEGIN
    -- Get all matches in this category without confirmed referee
    FOR v_match IN
        SELECT m.id, m.round_name, c.tournament_id
        FROM matches m
        JOIN categories c ON c.id = m.category_id
        WHERE m.category_id = p_category_id
        AND m.status IN ('SCHEDULED', 'CALLING')
        AND NOT EXISTS (
            SELECT 1 FROM referee_assignments ra
            WHERE ra.match_id = m.id AND ra.is_confirmed = TRUE
        )
        ORDER BY
            CASE m.round_name
                WHEN 'Final' THEN 1
                WHEN 'Semi-Final' THEN 2
                WHEN 'Quarter-Final' THEN 3
                ELSE 4
            END,
            m.id
    LOOP
        -- Get available referees for this match
        SELECT ARRAY(
            SELECT ar.user_id
            FROM available_referees(ar.match_id) ar
            CROSS JOIN LATERAL (
                SELECT ar.user_id,
                       COALESCE(
                           (SELECT COUNT(*)
                            FROM referee_assignments ra2
                            WHERE ra2.user_id = ar.user_id AND ra2.is_confirmed = TRUE),
                           0
                       ) AS ref_count
            ) counts
            WHERE ar.match_id = v_match.id
            ORDER BY counts.ref_count ASC
            LIMIT 5
        ) INTO v_available_refs;

        -- Assign next referee in round-robin
        IF array_length(v_available_refs, 1) > 0 THEN
            v_ref_idx := (v_ref_idx % array_length(v_available_refs, 1)) + 1;

            INSERT INTO referee_assignments (match_id, user_id, assigned_by, is_suggested)
            VALUES (v_match.id, v_available_refs[v_ref_idx], auth.uid(), TRUE)
            ON CONFLICT (match_id)
            DO UPDATE SET
                user_id = v_available_refs[v_ref_idx],
                is_suggested = TRUE,
                is_confirmed = FALSE,
                assigned_by = EXCLUDED.assigned_by;

            match_id := v_match.id;
            user_id := v_available_refs[v_ref_idx];
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 10. validate_score
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION validate_score(
    p_match_id UUID,
    p_set_number INTEGER,
    p_points_a INTEGER,
    p_points_b INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SET search_path TO extensions, public
AS $$
DECLARE
    v_sport_id UUID;
    v_points_per_set INTEGER;
    v_win_margin INTEGER;
    v_game_mode TEXT;
BEGIN
    -- Get sport config
    SELECT 
        s.scoring_config->>'scoring'->>'points_per_set',
        s.scoring_config->>'scoring'->>'win_margin',
        s.scoring_config->>'scoring'->>'game_mode'
    INTO v_points_per_set, v_win_margin, v_game_mode
    FROM matches m
    JOIN categories c ON c.id = m.category_id
    JOIN tournaments t ON t.id = c.tournament_id
    JOIN sports s ON s.id = t.sport_id
    WHERE m.id = p_match_id;

    -- Default values if not configured
    v_points_per_set := COALESCE(v_points_per_set::INTEGER, 11);
    v_win_margin := COALESCE(v_win_margin::INTEGER, 2);
    v_game_mode := COALESCE(v_game_mode, 'STANDARD');

    -- Validation based on game mode
    IF v_game_mode = 'TENNIS_15_30_40' THEN
        -- Tennis: must reach at least 4 points, win by 2
        IF p_points_a >= 4 AND p_points_a - p_points_b >= v_win_margin THEN
            RETURN TRUE;
        ELSIF p_points_b >= 4 AND p_points_b - p_points_a >= v_win_margin THEN
            RETURN TRUE;
        END IF;
    ELSIF v_game_mode = 'DEUCE' THEN
        -- Table tennis/pickleball with deuce: 10-10 requires win by 2
        IF p_points_a >= v_points_per_set AND p_points_a - p_points_b >= v_win_margin THEN
            RETURN TRUE;
        ELSIF p_points_b >= v_points_per_set AND p_points_b - p_points_a >= v_win_margin THEN
            RETURN TRUE;
        ELSIF p_points_a < v_points_per_set AND p_points_b < v_points_per_set 
            AND ABS(p_points_a - p_points_b) >= v_win_margin THEN
            RETURN TRUE;
        END IF;
    ELSE
        -- Standard: win by reaching points with margin
        IF p_points_a >= v_points_per_set AND p_points_a - p_points_b >= v_win_margin THEN
            RETURN TRUE;
        ELSIF p_points_b >= v_points_per_set AND p_points_b - p_points_a >= v_win_margin THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────

SELECT 
    'RPC SECURITY DEFINER Migration' AS migration,
    COUNT(*) AS functions_updated
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND prosrc LIKE '%SECURITY DEFINER%'
AND proname IN (
    'create_round_robin_group', 'generate_round_robin_matches',
    'offer_third_place', 'accept_third_place', 'create_third_place_match',
    'get_match_loser', 'assign_staff', 'invite_staff',
    'generate_referee_suggestions', 'validate_score'
);

-- ============================================================
-- END OF MIGRATION
-- ============================================================
