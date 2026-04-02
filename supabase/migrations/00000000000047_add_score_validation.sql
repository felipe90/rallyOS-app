-- Migration: Add score validation function and trigger
-- Validates score entries against sport-specific scoring rules

-- Create the validate_score function
CREATE OR REPLACE FUNCTION validate_score(p_match_id UUID, p_points_a INTEGER, p_points_b INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_scoring_config JSONB;
    v_points_to_win INTEGER;
    v_win_by_two BOOLEAN;
    v_scoring_type TEXT;
    v_has_golden_point BOOLEAN;
    v_deuce_at INTEGER;
    v_sport_id UUID;
BEGIN
    -- Get sport scoring config from the match
    SELECT t.sport_id INTO v_sport_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    WHERE m.id = p_match_id;

    IF v_sport_id IS NULL THEN
        -- No sport found, allow scoring (fallback to generic)
        RETURN TRUE;
    END IF;

    -- Get scoring config for the sport
    SELECT scoring_config INTO v_scoring_config
    FROM sports
    WHERE id = v_sport_id;

    IF v_scoring_config IS NULL THEN
        -- No scoring config, allow (generic mode)
        RETURN TRUE;
    END IF;

    -- Extract relevant config values
    v_points_to_win := COALESCE(
        (v_scoring_config->'game_scoring'->>'points_to_win_game')::INTEGER,
        (v_scoring_config->'scoring'->>'points_per_set')::INTEGER,
        (v_scoring_config->>'points_per_set')::INTEGER,
        11
    );
    
    v_win_by_two := COALESCE(
        (v_scoring_config->'game_scoring'->>'win_by_two_points')::BOOLEAN,
        (v_scoring_config->'scoring'->>'win_margin')::INTEGER > 0,
        TRUE
    );
    
    v_scoring_type := COALESCE(
        (v_scoring_config->'game_scoring'->>'scoring_type')::TEXT,
        (v_scoring_config->>'type')::TEXT,
        'standard'
    );
    
    v_has_golden_point := COALESCE(
        (v_scoring_config->'game_scoring'->>'has_golden_point')::BOOLEAN,
        FALSE
    );
    
    v_deuce_at := COALESCE(
        (v_scoring_config->'game_scoring'->>'deuce_at')::INTEGER,
        (v_scoring_config->>'deuce_at')::INTEGER,
        10
    );

    -- ═══════════════════════════════════════════════════════════════
    -- Validate based on scoring type
    -- ═══════════════════════════════════════════════════════════════
    
    -- Handle NULL scores (allow for match in progress)
    IF p_points_a IS NULL OR p_points_b IS NULL THEN
        RETURN TRUE;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Tennis 15-30-40 scoring (also Padel)
    -- ═══════════════════════════════════════════════════════════════
    IF v_scoring_type = 'tennis_15_30_40' THEN
        -- Points stored as 0, 1, 2, 3 representing 0, 15, 30, 40
        
        -- If scores below deuce (3-3), validate basic win-by-2
        IF p_points_a < 3 AND p_points_b < 3 THEN
            -- Both below 40: winner must have lead of at least 2
            IF p_points_a >= v_points_to_win AND p_points_a - p_points_b < 2 THEN
                RAISE EXCEPTION 'Invalid game score: must win by 2 points';
            END IF;
            IF p_points_b >= v_points_to_win AND p_points_b - p_points_a < 2 THEN
                RAISE EXCEPTION 'Invalid game score: must win by 2 points';
            END IF;
        END IF;
        
        -- At deuce (3-3) with golden point: next point wins
        IF v_has_golden_point AND p_points_a = 3 AND p_points_b = 3 THEN
            -- Golden point: any score > 3 means game over
            -- Just allow it (score should be >= 4 for winner)
            NULL;
        ELSIF p_points_a >= 3 AND p_points_b >= 3 THEN
            -- Regular advantage scoring: need 2-point lead
            IF ABS(p_points_a - p_points_b) < 2 THEN
                RAISE EXCEPTION 'Invalid game score at deuce: must win by 2 points';
            END IF;
        END IF;
        
        RETURN TRUE;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Standard/Rally scoring (Pickleball, Table Tennis)
    -- ═══════════════════════════════════════════════════════════════
    IF v_scoring_type = 'standard' OR v_scoring_type = 'rally' THEN
        -- Check for deuce in games that go to 11+ (like Table Tennis)
        IF v_points_to_win = 11 AND p_points_a >= v_deuce_at AND p_points_b >= v_deuce_at THEN
            -- At deuce: need 2-point lead
            IF ABS(p_points_a - p_points_b) < 2 THEN
                RAISE EXCEPTION 'Invalid game score at deuce (10-10): must win by 2 points';
            END IF;
        END IF;

        -- Regular win-by-2 validation
        IF v_win_by_two THEN
            IF p_points_a >= v_points_to_win AND p_points_a - p_points_b < 2 AND p_points_b >= v_points_to_win - 1 THEN
                RAISE EXCEPTION 'Invalid game score: must win by 2 points';
            END IF;
            IF p_points_b >= v_points_to_win AND p_points_b - p_points_a < 2 AND p_points_a >= v_points_to_win - 1 THEN
                RAISE EXCEPTION 'Invalid game score: must win by 2 points';
            END IF;
        END IF;

        RETURN TRUE;
    END IF;

    -- Generic mode - allow any score
    RETURN TRUE;
END;
$$;

-- Create the trigger function
CREATE OR REPLACE FUNCTION trg_validate_score()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate points_a vs points_b
    IF NOT validate_score(NEW.match_id, NEW.points_a, NEW.points_b) THEN
        RAISE EXCEPTION 'Invalid score for this sport';
    END IF;

    RETURN NEW;
END;
$$;

-- Add the trigger to scores table (BEFORE INSERT/UPDATE)
DROP TRIGGER IF EXISTS trg_validate_score ON scores;
CREATE TRIGGER trg_validate_score
    BEFORE INSERT OR UPDATE ON scores
    FOR EACH ROW
    EXECUTE FUNCTION trg_validate_score();

-- Add comment for documentation
COMMENT ON FUNCTION validate_score(UUID, INTEGER, INTEGER) IS 'Validates score entries against sport-specific scoring rules. Returns TRUE if valid, raises exception if invalid.';
COMMENT ON FUNCTION trg_validate_score() IS 'Trigger that validates scores before insert/update based on sport configuration.';