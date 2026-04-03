-- ============================================================
-- RALLYOS: Post-Match Feedback Tests
-- ============================================================
-- Tests for CU-06: Post-Match Feedback Backend
-- ============================================================

\echo ''
\echo '=============================================='
\echo 'POST-MATCH FEEDBACK TEST SUITE'
\echo '=============================================='

-- TEST 1: Achievements Catalog
\echo ''
\echo '[TEST 1] Achievements catalog populated'

SELECT 
    CASE 
        WHEN COUNT(*) >= 15 THEN '✅ PASS: ' || COUNT(*) || ' achievements seeded'
        ELSE '❌ FAIL: Only ' || COUNT(*) || ' achievements'
    END as result,
    'Icon types: ' || string_agg(DISTINCT icon_slug, ', ') as icon_types
FROM achievements;

-- TEST 2: Achievement Categories (grouped by icon_slug)
\echo ''
\echo '[TEST 2] Achievement categories distribution'

SELECT icon_slug, COUNT(*) as count, 
    string_agg(name, ', ') as achievements
FROM achievements
GROUP BY icon_slug
ORDER BY icon_slug;

-- TEST 3: RPC get_share_card_data
\echo ''
\echo '[TEST 3] get_share_card_data function'

DO $$
DECLARE
    v_result JSONB;
BEGIN
    v_result := get_share_card_data(
        '00000000-0000-0002-0000-000000000001'::UUID,
        '00000000-0000-0000-0000-000000000001'::UUID
    );
    
    RAISE NOTICE '✅ Share card generated for "El Pro"';
    RAISE NOTICE '   Current ELO: %', v_result->>'current_elo';
    RAISE NOTICE '   Matches played: %', v_result->>'matches_played';
    RAISE NOTICE '   Achievement count: %', v_result->>'achievement_count';
END $$;

-- TEST 4: RPC get_leaderboard
\echo ''
\echo '[TEST 4] get_leaderboard function'

SELECT * FROM get_leaderboard(
    '00000000-0000-0000-0000-000000000001'::UUID,
    10, 0
);

-- TEST 5: v_elo_history_with_context view
\echo ''
\echo '[TEST 5] ELO history with context view'

SELECT 
    person_id,
    opponent_name,
    result,
    elo_change,
    created_at::DATE as match_date
FROM v_elo_history_with_context
WHERE sport_id = '00000000-0000-0000-0000-000000000001'::UUID
ORDER BY created_at DESC
LIMIT 5;

-- TEST 6: v_player_profile_summary view
\echo ''
\echo '[TEST 6] Player profile summary view'

SELECT 
    nickname,
    current_elo,
    matches_played,
    win_rate_pct,
    achievement_count
FROM v_player_profile_summary
WHERE sport_id = '00000000-0000-0000-0000-000000000001'::UUID
ORDER BY current_elo DESC
LIMIT 5;

-- TEST 7: RLS on achievements
\echo ''
\echo '[TEST 7] RLS policies on achievements tables'

SELECT 
    tablename,
    policyname,
    cmd,
    CASE WHEN cmd = 'SELECT' THEN '✅' ELSE '❌' END as status
FROM pg_policies
WHERE tablename IN ('achievements', 'player_achievements')
ORDER BY tablename, cmd;

-- TEST 8: Triggers active
\echo ''
\echo '[TEST 8] Achievement triggers'

SELECT 
    tgname as trigger_name,
    relname as table_name,
    CASE 
        WHEN tgname LIKE '%achievement%' THEN '✅ Achievement trigger'
        ELSE '⚠️  Other trigger'
    END as status
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE tgname NOT LIKE 'pg_%'
AND (
    tgname LIKE '%achievement%' OR
    relname = 'matches' OR
    relname = 'athlete_stats'
)
ORDER BY relname, tgname;

-- TEST 9: Achievement columns in DB
\echo ''
\echo '[TEST 9] Achievement table schema'

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'achievements'
ORDER BY ordinal_position;

-- TEST 10: Share card structure
\echo ''
\echo '[TEST 10] Share card data structure'

DO $$
DECLARE
    v_card JSONB;
BEGIN
    v_card := get_share_card_data(
        '00000000-0000-0002-0000-000000000001'::UUID,
        '00000000-0000-0000-0000-000000000001'::UUID
    );
    
    -- Validate structure
    IF v_card ? 'person_name' AND 
       v_card ? 'current_elo' AND 
       v_card ? 'matches_played' AND
       v_card ? 'achievements' THEN
        RAISE NOTICE '✅ Share card has all required fields';
    ELSE
        RAISE NOTICE '❌ Share card missing fields';
    END IF;
    
    -- Validate types
    IF jsonb_typeof(v_card->'current_elo') = 'number' AND
       jsonb_typeof(v_card->'achievement_count') = 'number' THEN
        RAISE NOTICE '✅ Share card has correct types';
    ELSE
        RAISE NOTICE '❌ Share card has incorrect types';
    END IF;
END $$;

\echo ''
\echo '=============================================='
\echo 'POST-MATCH FEEDBACK TEST SUITE COMPLETE'
\echo '=============================================='
