-- ============================================================
-- RALLYOS: SECURITY TEST SUITE
-- ============================================================
-- Run these AFTER seed.sql is loaded.
-- Each test block has an EXPECTED RESULT comment.
-- Against a staging Supabase instance with real auth.users, 
-- replace the JWT tokens to simulate different roles.
--
-- HOW TO RUN:
--   psql postgres://postgres:postgres@localhost:54322/postgres \
--       -f db/tests/security_tests.sql
-- ============================================================

\echo ''
\echo '=============================================='
\echo 'RALLYOS SECURITY TEST SUITE'
\echo '=============================================='

-- ────────────────────────────────────────
-- TEST 1: UNAUTHORIZED REFEREE ATTACK
-- Simulates a player (non-referee) trying to directly
-- update a score record. RLS should block this.
-- ────────────────────────────────────────
\echo ''
\echo '[TEST 1] Unauthorized score update (should be BLOCKED by RLS)'
\echo 'NOTE: In Supabase, set role via: SET LOCAL role TO authenticated;'
\echo '      and SET request.jwt.claims.sub TO <non-referee-user-id>;'

-- When run with a normal user JWT (no referee role), 
-- this UPDATE must return: "ERROR: new row violates row-level security policy"
-- For local schema-only test, we verify the RLS policy EXISTS:

SELECT
    tablename,
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'scores'
ORDER BY policyname;

-- EXPECTED: At least 1 policy restricting UPDATE to referee_id = auth.uid()
-- If 0 rows → RLS policy for scores is MISSING ❌

\echo ''
\echo '[TEST 1 RESULT CHECK]'
SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASS: RLS policy on scores table exists'
    ELSE '❌ FAIL: No RLS policy on scores table — CRITICAL VULNERABILITY'
  END AS result
FROM pg_policies
WHERE tablename = 'scores';


-- ────────────────────────────────────────
-- TEST 2: ELO HISTORY IMMUTABILITY
-- Verifies that the elo_history table (if present) has
-- INSERT-only access for authenticated users.
-- The correct design has NO direct client INSERT on elo_history.
-- ────────────────────────────────────────
\echo ''
\echo '[TEST 2] ELO History immutability (INSERT-only via trigger)'

SELECT
    tablename,
    policyname,
    cmd
FROM pg_policies
WHERE tablename = 'elo_history'
ORDER BY cmd;

-- EXPECTED: No INSERT policy for 'authenticated' role.
--           Only triggers (SECURITY DEFINER) should write here.

SELECT
  CASE
    WHEN COUNT(*) = 0 THEN '✅ PASS: No client-accessible INSERT policy on elo_history (trigger-only write)'
    ELSE '⚠️  WARN: elo_history has a client-accessible policy — verify it is not writable'
  END AS result
FROM pg_policies
WHERE tablename = 'elo_history' AND cmd = 'INSERT';


-- ────────────────────────────────────────
-- TEST 3: PII DATA LEAKAGE VIA SNAPSHOT VIEW
-- Verifies that the public_tournament_snapshot view does NOT
-- expose sensitive fields like email, phone, or created_at.
-- ────────────────────────────────────────
\echo ''
\echo '[TEST 3] PII leakage check on public_tournament_snapshot view'

-- Check if the view exists
SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ INFO: public_tournament_snapshot view exists'
    ELSE '❌ FAIL: public_tournament_snapshot view is MISSING — PII risk on direct table access'
  END AS result
FROM information_schema.views
WHERE table_name = 'public_tournament_snapshot';

-- Check that forbidden columns are NOT in the view
SELECT
  column_name,
  CASE
    WHEN column_name IN ('email', 'phone', 'encrypted_password', 'user_id') THEN '❌ FAIL: PII column exposed — ' || column_name
    ELSE '✅ SAFE: ' || column_name
  END AS pii_check
FROM information_schema.columns
WHERE table_name = 'public_tournament_snapshot'
ORDER BY column_name;

-- EXPECTED: No rows with ❌ FAIL


-- ────────────────────────────────────────
-- TEST 4: TIME-TAMPERING (OFFLINE SYNC EXPLOIT)
-- Simulates a malicious payload with a far-future timestamp
-- for local_updated_at. The check_offline_sync_conflict trigger
-- must reject it.
-- ────────────────────────────────────────
\echo ''
\echo '[TEST 4] Time-tampering via future timestamp (should be BLOCKED by trigger)'

-- Verify the trigger function exists
SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASS: check_offline_sync_conflict trigger function exists'
    ELSE '❌ FAIL: check_offline_sync_conflict trigger is MISSING — time-tampering is possible'
  END AS result
FROM pg_proc
WHERE proname = 'check_offline_sync_conflict';

-- Verify the trigger is attached to the matches table
SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASS: Trigger is attached to matches table'
    ELSE '❌ FAIL: Trigger not attached to matches — players can submit backdated results'
  END AS result
FROM pg_trigger
WHERE tgname LIKE '%offline_sync%'
   OR tgname LIKE '%sync_conflict%';


-- ────────────────────────────────────────
-- TEST 5: TOURNAMENT STAFF AUTHORIZATION TRAP
-- A user cannot self-insert into tournament_staff as ORGANIZER.
-- This must be enforced exclusively by the auto-trigger on tournament creation.
-- ────────────────────────────────────────
\echo ''
\echo '[TEST 5] Staff self-elevation prevention (ORGANIZER role via trigger only)'

SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASS: trg_tournament_created_assign_organizer trigger exists'
    ELSE '❌ FAIL: Auto-organizer trigger is MISSING — anyone can create tournament without ORGANIZER role'
  END AS result
FROM pg_trigger
WHERE tgname = 'trg_tournament_created_assign_organizer';

-- Also verify RLS policy exists preventing self-insertion
SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASS: RLS policy on tournament_staff exists'
    ELSE '❌ FAIL: No RLS on tournament_staff — privilege escalation is possible'
  END AS result
FROM pg_policies
WHERE tablename = 'tournament_staff';


-- ────────────────────────────────────────
-- SEED VERIFICATION QUERIES
-- Confirm the seed data loaded correctly
-- ────────────────────────────────────────
\echo ''
\echo '=============================================='
\echo 'SEED DATA VERIFICATION'
\echo '=============================================='

\echo '[Verify] Match count by status (expect: 1 FINISHED, 1 LIVE, 1 SCHEDULED)'
SELECT status, COUNT(*) as total FROM matches GROUP BY status;

\echo '[Verify] UPSET in community_feed (expect: 1 row)'
SELECT event_type, payload_json->>'message' AS message
FROM community_feed
WHERE event_type = 'UPSET';

\echo '[Verify] Player ELOs (expect: 4 players, ELOs between 900-1200)'
SELECT p.nickname, a.current_elo, a.matches_played
FROM athlete_stats a
JOIN persons p ON p.id = a.person_id
ORDER BY a.current_elo DESC;

\echo '[Verify] Payments (expect: 4 SUCCEEDED payments of $25.00 each)'
SELECT te.display_name, p.provider, p.amount / 100.0 AS amount_usd, p.status
FROM payments p
JOIN tournament_entries te ON te.id = p.tournament_entry_id
ORDER BY te.display_name;

\echo ''
\echo '=============================================='
\echo 'SECURITY TEST SUITE COMPLETE'
\echo '=============================================='
