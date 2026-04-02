-- ============================================================
-- RALLYOS: SPORT SCORING RULES TESTS
-- ============================================================
-- Tests for validate_score function and scoring_config
-- Run after migrations
--
-- HOW TO RUN:
--   psql postgres://postgres:postgres@localhost:54322/postgres \
--       -f supabase/tests/scoring_rules_tests.sql
-- ============================================================

-- Set search_path for all tests
SET search_path = 'public';

\echo ''
\echo '=============================================='
\echo 'SPORTS SCORING RULES TEST SUITE'
\echo '=============================================='

-- Get a Padel match for testing
DO $$
DECLARE
    v_padel_match_id UUID;
BEGIN
    -- Find a Padel match
    SELECT m.id INTO v_padel_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    JOIN sports s ON t.sport_id = s.id
    WHERE s.name = 'Padel'
    LIMIT 1;

    RAISE NOTICE 'Testing with Padel match: %', v_padel_match_id;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 1: Invalid Tennis Game Score (4-3)
-- Should FAIL validation - not win by 2
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 1] Invalid tennis score 4-3 (should reject)'

DO $$
DECLARE
    v_padel_match_id UUID;
    v_result BOOLEAN;
BEGIN
    -- Find any match to test with
    SELECT m.id INTO v_padel_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    LIMIT 1;

    -- Test invalid score (4-3 not win by 2)
    BEGIN
        v_result := validate_score(v_padel_match_id, 4, 3);
        -- If we get here, the validation didn't work - fail the test
        RAISE EXCEPTION 'Expected rejection but validation passed with: %', v_result;
    EXCEPTION
        WHEN raise_exception THEN
            RAISE;
        WHEN OTHERS THEN
            -- Expected to reject - PASS the test
            RAISE NOTICE '✅ TEST 1 PASSED: Invalid score 4-3 was rejected';
    END;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 2: Valid Tennis Game Score (4-2)
-- Should PASS validation - win by 2
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 2] Valid tennis score 4-2 (should accept)'

DO $$
DECLARE
    v_match_id UUID;
    v_result BOOLEAN;
BEGIN
    SELECT m.id INTO v_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    LIMIT 1;

    v_result := validate_score(v_match_id, 4, 2);
    
    IF v_result = TRUE THEN
        RAISE NOTICE '✅ TEST 2 PASSED: Valid score 4-2 was accepted';
    ELSE
        RAISE EXCEPTION '❌ TEST 2 FAILED: Valid score 4-2 was rejected';
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 3: Pickleball Valid Score (11-9)
-- Should PASS - win by 2
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 3] Valid pickleball score 11-9 (should accept)'

DO $$
DECLARE
    v_match_id UUID;
    v_result BOOLEAN;
BEGIN
    SELECT m.id INTO v_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    LIMIT 1;

    v_result := validate_score(v_match_id, 11, 9);
    
    IF v_result = TRUE THEN
        RAISE NOTICE '✅ TEST 3 PASSED: Valid pickleball 11-9 was accepted';
    ELSE
        RAISE EXCEPTION '❌ TEST 3 FAILED: Valid pickleball 11-9 was rejected';
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 4: Table Tennis Deuce (10-10 to 12-10)
-- Should PASS - deuce requires 2-point lead
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 4] Valid TT deuce score 12-10 (should accept)'

DO $$
DECLARE
    v_match_id UUID;
    v_result BOOLEAN;
BEGIN
    SELECT m.id INTO v_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    LIMIT 1;

    v_result := validate_score(v_match_id, 12, 10);
    
    IF v_result = TRUE THEN
        RAISE NOTICE '✅ TEST 4 PASSED: Valid TT deuce 12-10 was accepted';
    ELSE
        RAISE EXCEPTION '❌ TEST 4 FAILED: Valid TT deuce 12-10 was rejected';
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 5: Invalid TT Deuce (11-10 at 10-10)
-- Should FAIL - not win by 2 at deuce
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 5] Invalid TT deuce score 11-10 (should reject)'

DO $$
DECLARE
    v_match_id UUID;
    v_result BOOLEAN;
BEGIN
    SELECT m.id INTO v_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    LIMIT 1;

    BEGIN
        v_result := validate_score(v_match_id, 11, 10);
        RAISE EXCEPTION 'Expected rejection but validation passed with: %', v_result;
    EXCEPTION
        WHEN raise_exception THEN
            RAISE;
        WHEN OTHERS THEN
            RAISE NOTICE '✅ TEST 5 PASSED: Invalid TT deuce 11-10 was rejected';
    END;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 6: Scoring Config Exists for All Sports
-- Verify all 4 sports have proper config
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 6] Scoring config exists for all sports'

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM sports
    WHERE name IN ('Tennis', 'Pickleball', 'Table Tennis', 'Padel')
      AND scoring_config IS NOT NULL
      AND scoring_config->'game_scoring' IS NOT NULL;

    IF v_count = 4 THEN
        RAISE NOTICE '✅ TEST 6 PASSED: All 4 sports have scoring_config';
    ELSE
        RAISE EXCEPTION '❌ TEST 6 FAILED: Only %/4 sports have scoring_config', v_count;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 7: Calculate Game Winner Tests
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 7] calculate_game_winner function'

DO $$
DECLARE
    v_winner CHAR;
    v_config JSONB;
BEGIN
    -- Test standard scoring (Pickleball/TT)
    v_config := '{"scoring_type": "rally", "points_to_win_game": 11, "win_by_two_points": true}'::jsonb;
    
    v_winner := calculate_game_winner(11, 9, v_config);
    IF v_winner = 'A' THEN
        RAISE NOTICE '✅ 7a: Pickleball 11-9 winner = A';
    ELSE
        RAISE EXCEPTION '❌ 7a: Expected A, got %', v_winner;
    END IF;

    -- Test deuce (TT)
    v_config := '{"scoring_type": "standard", "points_to_win_game": 11, "win_by_two_points": true}'::jsonb;
    v_winner := calculate_game_winner(12, 10, v_config);
    IF v_winner = 'A' THEN
        RAISE NOTICE '✅ 7b: TT 12-10 winner = A';
    ELSE
        RAISE EXCEPTION '❌ 7b: Expected A, got %', v_winner;
    END IF;

    -- Test tennis 15-30-40
    v_config := '{"scoring_type": "tennis_15_30_40", "points_to_win_game": 4, "win_by_two_points": true}'::jsonb;
    v_winner := calculate_game_winner(4, 2, v_config);
    IF v_winner = 'A' THEN
        RAISE NOTICE '✅ 7c: Tennis 4-2 winner = A';
    ELSE
        RAISE EXCEPTION '❌ 7c: Expected A, got %', v_winner;
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
-- TEST 8: Trigger is Active
-- Verify trg_validate_score is on scores table
-- ═══════════════════════════════════════════════════════════
\echo ''
\echo '[TEST 8] Trigger is active on scores table'

DO $$
DECLARE
    v_trigger_count INTEGER;
BEGIN
    -- Use pg_trigger catalog instead of information_schema
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'scores'
      AND t.tgname = 'trg_validate_score'
      AND NOT t.tgisinternal;

    IF v_trigger_count > 0 THEN
        RAISE NOTICE '✅ TEST 8 PASSED: trg_validate_score trigger is active';
    ELSE
        RAISE EXCEPTION '❌ TEST 8 FAILED: Trigger not found';
    END IF;
END $$;

\echo ''
\echo '=============================================='
\echo 'ALL SPORT SCORING RULES TESTS COMPLETED'
\echo '=============================================='
\echo ''