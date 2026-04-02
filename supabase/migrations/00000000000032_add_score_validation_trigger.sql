-- ============================================================
-- Migration: 00000000000032_add_score_validation_trigger
-- Purpose: Task 2 - Score validation function and trigger
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Step 0: Ensure scoring_config column exists in sports table
-- (May have been added in previous migration, ensure it's present)
-- ═══════════════════════════════════════════════════════════════
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sports' AND column_name = 'scoring_config'
    ) THEN
        ALTER TABLE sports
        ADD COLUMN scoring_config JSONB NOT NULL DEFAULT '{
            "type": "generic",
            "points_per_set": 11,
            "best_of_sets": 3,
            "win_by_2": true,
            "tie_break": {
                "enabled": true,
                "at": 10,
                "points": 7
            },
            "golden_point": {
                "enabled": true,
                "min_difference": 2
            },
            "scoring_system": "standard",
            "win_condition": "points"
        }'::jsonb;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- Step 1: Create validate_score() function
-- SECURITY DEFINER to bypass RLS when needed
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION validate_score(
    p_match_id UUID,
    p_points_a INTEGER,
    p_points_b INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_scoring_config JSONB;
    v_points_per_set INTEGER;
    v_win_by_2 BOOLEAN;
    v_tiebreak_at INTEGER;
    v_tiebreak_points INTEGER;
    v_golden_point BOOLEAN;
    v_min_difference INTEGER;
    v_max_points INTEGER;
    v_winner_a BOOLEAN;
    v_winner_points INTEGER;
    v_loser_points INTEGER;
BEGIN
    -- Get scoring_config from match's sport (via category -> tournament -> sport)
    SELECT COALESCE(s.scoring_config, 
        jsonb_build_object(
            'points_per_set', COALESCE(s.default_points_per_set, 11),
            'win_by_2', true,
            'tie_break', jsonb_build_object('enabled', true, 'points', 7),
            'golden_point', jsonb_build_object('enabled', true, 'min_difference', 2)
        )
    ) INTO v_scoring_config
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    JOIN sports s ON t.sport_id = s.id
    WHERE m.id = p_match_id;

    -- Extract scoring parameters with defaults
    v_points_per_set := COALESCE(
        (v_scoring_config->>'points_per_set')::INTEGER,
        11
    );
    
    v_win_by_2 := COALESCE(
        (v_scoring_config->>'win_by_2')::BOOLEAN,
        TRUE
    );
    
    v_tiebreak_at := COALESCE(
        (v_scoring_config->'tie_break'->>'at')::INTEGER,
        10
    );
    
    v_tiebreak_points := COALESCE(
        (v_scoring_config->'tie_break'->>'points')::INTEGER,
        7
    );
    
    v_golden_point := COALESCE(
        (v_scoring_config->'golden_point'->>'enabled')::BOOLEAN,
        TRUE
    );
    
    v_min_difference := COALESCE(
        (v_scoring_config->'golden_point'->>'min_difference')::INTEGER,
        (v_scoring_config->>'min_difference')::INTEGER,
        2
    );

    -- Calculate max valid points (for win-by-2, we allow going beyond points_per_set)
    v_max_points := v_points_per_set + v_min_difference + 10;

    -- Validate score ranges
    IF p_points_a < 0 OR p_points_b < 0 THEN
        RAISE EXCEPTION 'Score cannot be negative. Got: points_a=%, points_b=%', p_points_a, p_points_b;
    END IF;

    -- Allow 0-0 as initial state (game not started)
    IF p_points_a = 0 AND p_points_b = 0 THEN
        RETURN TRUE;
    END IF;

    IF p_points_a > v_max_points OR p_points_b > v_max_points THEN
        RAISE EXCEPTION 'Score exceeds maximum allowed (%). Got: points_a=%, points_b=%', v_max_points, p_points_a, p_points_b;
    END IF;

    -- Determine winner and calculate difference
    IF p_points_a > p_points_b THEN
        v_winner_a := TRUE;
        v_winner_points := p_points_a;
        v_loser_points := p_points_b;
    ELSIF p_points_b > p_points_a THEN
        v_winner_a := FALSE;
        v_winner_points := p_points_b;
        v_loser_points := p_points_a;
    ELSE
        -- Tie scores are invalid (except in specific tiebreak scenarios)
        RAISE EXCEPTION 'Scores cannot be tied. Each player must have a different score.';
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Edge Case: TIEBREAK / GOLDEN POINT detection
    -- ═══════════════════════════════════════════════════════════════
    -- Golden point: When BOTH players reach tiebreak_at (e.g., 10-10 in Padel)
    -- At that point, winning requires 2 point lead but can go beyond points_per_set
    -- Examples: 12-10, 13-11, 14-12 (valid) vs 11-10 (invalid - not enough lead)
    IF v_golden_point AND p_points_a >= v_tiebreak_at AND p_points_b >= v_tiebreak_at THEN
        -- Golden point scenario: winner just needs min_difference lead
        IF v_winner_points >= v_loser_points + v_min_difference THEN
            RETURN TRUE; -- Valid golden point score (e.g., 12-10, 14-12)
        ELSE
            RAISE EXCEPTION 
                'Invalid golden point score. In golden point (at %-%), winner must lead by at least % points. Got: %-%',
                v_tiebreak_at, v_tiebreak_at, v_min_difference, p_points_a, p_points_b;
        END IF;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Standard scoring validation (win by 2 rule)
    -- ═══════════════════════════════════════════════════════════════
    IF v_win_by_2 THEN
        -- Winner must have at least points_per_set AND lead by 2+
        IF v_winner_points >= v_points_per_set AND v_winner_points >= v_loser_points + v_min_difference THEN
            RETURN TRUE;
        ELSIF v_winner_points >= v_points_per_set THEN
            RAISE EXCEPTION 
                'Invalid score: Win by % rule requires winner to have at least % points and lead by %. Got: %-%',
                v_min_difference, v_points_per_set, v_min_difference, p_points_a, p_points_b;
        ELSE
            RAISE EXCEPTION 
                'Invalid score: Winner must reach at least % points. Got: %-%',
                v_points_per_set, p_points_a, p_points_b;
        END IF;
    ELSE
        -- No win-by-2 required (some formats like boxing)
        -- Winner just needs to reach points_per_set
        IF v_winner_points >= v_points_per_set THEN
            RETURN TRUE;
        ELSE
            RAISE EXCEPTION 
                'Invalid score: Winner must reach at least % points. Got: %-%',
                v_points_per_set, p_points_a, p_points_b;
        END IF;
    END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- Step 2: Create trigger function for scores table
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION trg_validate_score()
RETURNS TRIGGER AS $$
DECLARE
    v_valid BOOLEAN;
BEGIN
    -- Skip validation if match_id is NULL (allowing row creation without match)
    IF NEW.match_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Validate current set scores (points_a and points_b)
    v_valid := validate_score(
        NEW.match_id,
        NEW.points_a,
        NEW.points_b
    );

    -- If validation passes, v_valid is TRUE; otherwise exception was raised
    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid score values for match %', NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- Step 3: Create trigger on scores table
-- BEFORE INSERT OR UPDATE - rejects invalid scores
-- ═══════════════════════════════════════════════════════════════
DROP TRIGGER IF EXISTS trg_validate_score ON scores;

CREATE TRIGGER trg_validate_score
    BEFORE INSERT OR UPDATE ON scores
    FOR EACH ROW
    EXECUTE FUNCTION trg_validate_score();

-- ═══════════════════════════════════════════════════════════════
-- Step 4: Grant execute to authenticated users
-- (so they can call validate_score directly if needed)
-- ═══════════════════════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION validate_score(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION trg_validate_score() TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- Step 5: Add index for performance (if not exists)
-- ═══════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_scores_match_id ON scores(match_id);

COMMENT ON FUNCTION validate_score(UUID, INTEGER, INTEGER) IS 
'Validates a score for a match based on the sport''s scoring configuration.
Returns TRUE if valid, raises exception if invalid.
Handles: win-by-2 rule, tiebreak detection, golden point (Padel/TT at 10-10).';

COMMENT ON TRIGGER trg_validate_score ON scores IS 
'BEFORE INSERT/UPDATE trigger that validates score values against sport scoring rules.
Rejects invalid scores (e.g., 11-10 without golden point, scores below winning threshold).';

COMMIT;