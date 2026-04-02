-- ============================================
-- Task 3: Create game/set winner calculation functions
-- Purpose: Sport-specific scoring logic for bracket advancement
-- ============================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Helper: is_tiebreak
-- Returns TRUE if scores indicate a tiebreak situation
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION is_tiebreak(
    p_game_a INTEGER,
    p_game_b INTEGER,
    p_scoring_config JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_tiebreak_at INTEGER;
    v_has_tiebreak BOOLEAN;
BEGIN
    v_has_tiebreak := COALESCE(p_scoring_config->>'has_tiebreak', 'false')::BOOLEAN;
    v_tiebreak_at := COALESCE(p_scoring_config->>'tiebreak_at', 6)::INTEGER;

    -- No tiebreak if feature is disabled
    IF NOT v_has_tiebreak THEN
        RETURN FALSE;
    END IF;

    -- Tiebreak occurs when both players reach tiebreak_at (e.g., 6-6 in tennis)
    RETURN p_game_a = v_tiebreak_at AND p_game_b = v_tiebreak_at;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- Function: calculate_game_winner
-- Determines the winner of a single game based on sport-specific rules
-- Returns 'A' if player A wins, 'B' if player B wins, NULL if incomplete
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION calculate_game_winner(
    p_score_a INTEGER,
    p_score_b INTEGER,
    p_scoring_config JSONB
)
RETURNS CHAR(1)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_points_to_win INTEGER;
    v_win_by_two BOOLEAN;
    v_scoring_type TEXT;
    v_has_golden_point BOOLEAN;
    v_tiebreak_at INTEGER;
    v_has_tiebreak BOOLEAN;
BEGIN
    -- Handle NULL scores (game not started or in progress)
    IF p_score_a IS NULL OR p_score_b IS NULL THEN
        RETURN NULL;
    END IF;

    -- Extract config values with defaults
    -- Handle both naming conventions: points_to_win_game vs points_per_set
    v_points_to_win := COALESCE(
        (p_scoring_config->>'points_to_win_game')::INTEGER,
        (p_scoring_config->>'points_per_set')::INTEGER,
        4
    );
    v_win_by_two := COALESCE(
        (p_scoring_config->>'win_by_two_points')::BOOLEAN,
        (p_scoring_config->>'win_by_2')::BOOLEAN,
        TRUE
    );
    v_scoring_type := COALESCE(
        (p_scoring_config->>'scoring_type')::TEXT,
        (p_scoring_config->>'type')::TEXT,
        'standard'
    );
    v_has_golden_point := COALESCE(
        (p_scoring_config->>'has_golden_point')::BOOLEAN,
        (p_scoring_config->'golden_point'->>'enabled')::BOOLEAN,
        FALSE
    );
    v_tiebreak_at := COALESCE(
        (p_scoring_config->>'tiebreak_at')::INTEGER,
        (p_scoring_config->'tie_break'->>'at')::INTEGER,
        6
    );
    v_has_tiebreak := COALESCE(
        (p_scoring_config->>'has_tiebreak')::BOOLEAN,
        (p_scoring_config->'tie_break'->>'enabled')::BOOLEAN,
        FALSE
    );

    -- ═══════════════════════════════════════════════════════════════
    -- Handle Tennis 15-30-40 scoring (also used for Padel)
    -- ═══════════════════════════════════════════════════════════════
    IF v_scoring_type = 'tennis_15_30_40' THEN
        -- Standard points are 0, 15, 30, 40 (stored as 0, 1, 2, 3)
        -- v_points_to_win = 4 means first to 4 points (0,1,2,3, then 4+ wins)
        
        -- Check for deuce (40-40 = 3-3)
        IF p_score_a = 3 AND p_score_b = 3 THEN
            -- Deuce state - game not complete yet
            RETURN NULL;
        END IF;

        -- Golden point: at 40-40 (3-3), next point wins (for Padel)
        IF v_has_golden_point AND (p_score_a = 3 OR p_score_b = 3) THEN
            -- Any score beyond 3 means golden point was won
            IF p_score_a > 3 AND p_score_a > p_score_b THEN
                RETURN 'A';
            ELSIF p_score_b > 3 AND p_score_b > p_score_a THEN
                RETURN 'B';
            ELSE
                -- Still at deuce or advantage not yet resolved
                RETURN NULL;
            END IF;
        END IF;

        -- Regular advantage scoring (tennis)
        IF p_score_a >= 3 AND p_score_b >= 3 THEN
            -- Advantage state: need 2-point lead
            IF p_score_a - p_score_b >= 2 THEN
                RETURN 'A';
            ELSIF p_score_b - p_score_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL; -- Not yet decided
            END IF;
        END IF;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Handle Standard/Rally scoring (Pickleball, Table Tennis)
    -- ═══════════════════════════════════════════════════════════════
    IF v_scoring_type = 'standard' OR v_scoring_type = 'rally' THEN
        -- Table Tennis deuce at 10-10
        IF v_points_to_win = 11 AND p_score_a >= 10 AND p_score_b >= 10 THEN
            -- Deuce state: need 2-point lead
            IF p_score_a - p_score_b >= 2 THEN
                RETURN 'A';
            ELSIF p_score_b - p_score_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL;
            END IF;
        END IF;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Generic scoring logic
    -- ═══════════════════════════════════════════════════════════════
    IF v_win_by_two THEN
        -- Win by 2 points
        -- Must reach points_to_win AND have 2-point lead
        
        -- Check minimum points reached
        IF p_score_a < v_points_to_win AND p_score_b < v_points_to_win THEN
            RETURN NULL; -- Neither has reached winning threshold
        END IF;

        -- Check for win by 2
        IF p_score_a >= v_points_to_win AND p_score_a - p_score_b >= 2 THEN
            RETURN 'A';
        ELSIF p_score_b >= v_points_to_win AND p_score_b - p_score_a >= 2 THEN
            RETURN 'B';
        ELSIF p_score_a >= v_points_to_win AND p_score_b >= v_points_to_win THEN
            -- Both at winning threshold but tied or 1-point lead
            RETURN NULL;
        ELSIF p_score_a >= v_points_to_win AND p_score_b < v_points_to_win - 1 THEN
            -- A won without B being able to catch up
            RETURN 'A';
        ELSIF p_score_b >= v_points_to_win AND p_score_a < v_points_to_win - 1 THEN
            -- B won without A being able to catch up
            RETURN 'B';
        ELSE
            RETURN NULL;
        END IF;
    ELSE
        -- Simple majority (not used currently, but supported)
        IF p_score_a >= v_points_to_win AND p_score_a > p_score_b THEN
            RETURN 'A';
        ELSIF p_score_b >= v_points_to_win AND p_score_b > p_score_a THEN
            RETURN 'B';
        ELSIF p_score_a >= v_points_to_win AND p_score_b >= v_points_to_win THEN
            RETURN NULL; -- Tie at winning threshold
        ELSE
            RETURN NULL;
        END IF;
    END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- Function: calculate_set_winner
-- Determines the winner of a set based on game scores
-- Returns 'A', 'B', or NULL if set is not complete
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION calculate_set_winner(
    p_sets JSONB,
    p_scoring_config JSONB
)
RETURNS CHAR(1)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_games_to_win INTEGER;
    v_win_by_two_games BOOLEAN;
    v_tiebreak_at INTEGER;
    v_has_tiebreak BOOLEAN;
    v_has_super_tiebreak BOOLEAN;
    v_super_tiebreak_points INTEGER;
    v_set_element JSONB;
    v_games_a INTEGER;
    v_games_b INTEGER;
    v_current_set_games_a INTEGER;
    v_current_set_games_b INTEGER;
    v_is_tb BOOLEAN;
BEGIN
    -- Handle NULL input
    IF p_sets IS NULL OR jsonb_array_length(p_sets) IS NULL OR jsonb_array_length(p_sets) = 0 THEN
        RETURN NULL;
    END IF;

    -- Extract config values
    v_games_to_win := COALESCE(p_scoring_config->>'games_to_win_set', 6)::INTEGER;
    v_win_by_two_games := COALESCE(p_scoring_config->>'win_by_two_games', 'true')::BOOLEAN;
    v_tiebreak_at := COALESCE(p_scoring_config->>'tiebreak_at', 6)::INTEGER;
    v_has_tiebreak := COALESCE(p_scoring_config->>'has_tiebreak', 'false')::BOOLEAN;
    v_has_super_tiebreak := COALESCE(p_scoring_config->>'has_super_tiebreak', 'false')::BOOLEAN;
    v_super_tiebreak_points := COALESCE(p_scoring_config->>'super_tiebreak_points', 10)::INTEGER;

    -- Iterate through all sets to count games won
    v_games_a := 0;
    v_games_b := 0;

    FOR v_set_element IN SELECT * FROM jsonb_array_elements(p_sets)
    LOOP
        -- Extract game scores from set
        -- Sets can be in format: [{"games": {"a": 6, "b": 4}}] or just [{"a": 6, "b": 4}]
        -- Check both formats for compatibility
        v_current_set_games_a := COALESCE((v_set_element->>'a')::INTEGER, (v_set_element->'games'->>'a')::INTEGER, 0);
        v_current_set_games_b := COALESCE((v_set_element->>'b')::INTEGER, (v_set_element->'games'->>'b')::INTEGER, 0);

        -- Check if this set is a tiebreak
        v_is_tb := is_tiebreak(v_current_set_games_a, v_current_set_games_b, p_scoring_config);

        IF v_is_tb THEN
            -- Tiebreak: check tiebreak points (stored in current set)
            -- For tiebreaks, we check if there's game score data
            -- The tiebreak winner is determined by points_a/points_b within the tiebreak
            -- For simplicity, we count games by who won the tiebreak
            IF v_current_set_games_a > v_current_set_games_b THEN
                v_games_a := v_games_a + 1;
            ELSIF v_current_set_games_b > v_current_set_games_a THEN
                v_games_b := v_games_b + 1;
            END IF;
        ELSIF v_current_set_games_a >= v_games_to_win OR v_current_set_games_b >= v_games_to_win THEN
            -- Normal set win - check if won by 2 if required
            IF v_win_by_two_games THEN
                IF v_current_set_games_a >= v_games_to_win 
                   AND v_current_set_games_a - v_current_set_games_b >= 2 THEN
                    v_games_a := v_games_a + 1;
                ELSIF v_current_set_games_b >= v_games_to_win 
                      AND v_current_set_games_b - v_current_set_games_a >= 2 THEN
                    v_games_b := v_games_b + 1;
                END IF;
            ELSE
                -- No win-by-two requirement
                IF v_current_set_games_a >= v_games_to_win THEN
                    v_games_a := v_games_a + 1;
                ELSIF v_current_set_games_b >= v_games_to_win THEN
                    v_games_b := v_games_b + 1;
                END IF;
            END IF;
        END IF;
    END LOOP;

    -- Check for super tiebreak (10 points win by 2 in Padel)
    IF v_has_super_tiebreak THEN
        -- Check the last set for super tiebreak scores
        v_set_element := p_sets->(jsonb_array_length(p_sets) - 1);
        v_current_set_games_a := COALESCE((v_set_element->>'a')::INTEGER, 0);
        v_current_set_games_b := COALESCE((v_set_element->>'b')::INTEGER, 0);

        -- Super tiebreak: typically at 6-6, played to 10 points win by 2
        IF v_current_set_games_a >= v_super_tiebreak_points - 1 
           AND v_current_set_games_b >= v_super_tiebreak_points - 1 THEN
            -- In super tiebreak
            IF v_current_set_games_a >= v_super_tiebreak_points 
               AND v_current_set_games_a - v_current_set_games_b >= 2 THEN
                RETURN 'A';
            ELSIF v_current_set_games_b >= v_super_tiebreak_points 
                  AND v_current_set_games_b - v_current_set_games_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL; -- Super tiebreak not complete
            END IF;
        END IF;
    END IF;

    -- Determine set winner
    IF v_games_a >= v_games_to_win THEN
        IF v_win_by_two_games THEN
            IF v_games_a - v_games_b >= 2 THEN
                RETURN 'A';
            ELSE
                RETURN NULL; -- Not won by 2 yet
            END IF;
        ELSE
            RETURN 'A';
        END IF;
    ELSIF v_games_b >= v_games_to_win THEN
        IF v_win_by_two_games THEN
            IF v_games_b - v_games_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL;
            END IF;
        ELSE
            RETURN 'B';
        END IF;
    ELSE
        RETURN NULL; -- Set not complete
    END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- Grant execute permissions
-- ═══════════════════════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION is_tiebreak(INTEGER, INTEGER, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_game_winner(INTEGER, INTEGER, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_set_winner(JSONB, JSONB) TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- Update trigger comment to reference these functions
-- ═══════════════════════════════════════════════════════════════
COMMENT ON FUNCTION is_tiebreak(INTEGER, INTEGER, JSONB) IS 
'Helper: Returns TRUE if game scores indicate a tiebreak situation (e.g., 6-6 in tennis)';
COMMENT ON FUNCTION calculate_game_winner(INTEGER, INTEGER, JSONB) IS 
'Returns game winner (A/B/NULL) based on scoring_config rules - handles tennis 15-30-40, deuce, golden point, standard rally scoring';
COMMENT ON FUNCTION calculate_set_winner(JSONB, JSONB) IS 
'Returns set winner (A/B/NULL) based on game scores and scoring_config - handles tiebreaks, super tiebreaks, win-by-2 rules';

COMMIT;
