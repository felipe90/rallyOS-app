-- ============================================================
-- RALLYOS: SEED DATA — Real-World Tournament Scenario
-- ============================================================
-- Scenario: "Copa Pádel Medellín 2026" - Singles Category
-- 4 players, 4 matches (semifinal + final), 1 UPSET event
-- Run after schema.sql in Supabase Studio or via supabase db reset
-- ============================================================

-- ────────────────────────────────────────
-- 1. SPORT
-- ────────────────────────────────────────
INSERT INTO sports (id, name, scoring_system, default_points_per_set, default_best_of_sets)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Padel', 'POINTS', 11, 5);

-- ────────────────────────────────────────
-- 2. TOURNAMENT
-- ────────────────────────────────────────
INSERT INTO tournaments (id, sport_id, name, status, handicap_enabled, use_differential)
VALUES
  ('00000000-0000-0000-0000-000000000010',
   '00000000-0000-0000-0000-000000000001',
   'Copa Pádel Medellín 2026',
   'LIVE',
   TRUE,
   TRUE);

-- ────────────────────────────────────────
-- 3. CATEGORY (Men's Singles A)
-- ────────────────────────────────────────
INSERT INTO categories (id, tournament_id, name, mode, points_override, sets_override, elo_min, elo_max)
VALUES
  ('00000000-0000-0000-0000-000000000020',
   '00000000-0000-0000-0000-000000000010',
   'Singles Masculino A',
   'SINGLES',
   11,    -- Win with 11 points
   5,     -- Best of 5 sets
   900,
   1200);

-- ────────────────────────────────────────
-- 4. PERSONS (Players — no auth.users link for local seed)
-- ────────────────────────────────────────
INSERT INTO persons (id, first_name, last_name, nickname)
VALUES
  ('00000000-0000-0000-0001-000000000001', 'Andres',  'Rojas',   'El Rayo'),
  ('00000000-0000-0000-0001-000000000002', 'Carlos',  'Perez',   'CP10'),
  ('00000000-0000-0000-0001-000000000003', 'Miguel',  'Torres',  'Migtorr'),
  ('00000000-0000-0000-0001-000000000004', 'Felipe',  'Wolf',    'FW');

-- ────────────────────────────────────────
-- 5. ATHLETE STATS (Initial ELOs)
-- ────────────────────────────────────────
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played)
VALUES
  ('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-000000000001', 1150, 32),
  ('00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0000-000000000001', 980,  18),
  ('00000000-0000-0000-0001-000000000003', '00000000-0000-0000-0000-000000000001', 1080, 24),
  ('00000000-0000-0000-0001-000000000004', '00000000-0000-0000-0000-000000000001', 1200, 45);

-- ────────────────────────────────────────
-- 6. TOURNAMENT ENTRIES (1 player = 1 entry in singles)
-- All entries are CONFIRMED since payments succeeded
-- fee_amount_snap = 2500 cents ($25.00 USD)
-- ────────────────────────────────────────
INSERT INTO tournament_entries (id, category_id, display_name, current_handicap, status, fee_amount_snap)
VALUES
  ('00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0000-000000000020', 'Andres Rojas',  -2, 'CONFIRMED', 2500),
  ('00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0000-000000000020', 'Carlos Perez',   2, 'CONFIRMED', 2500),
  ('00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0000-000000000020', 'Miguel Torres',  0, 'CONFIRMED', 2500),
  ('00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0000-000000000020', 'Felipe Wolf',   -3, 'CONFIRMED', 2500);

INSERT INTO entry_members (entry_id, person_id)
VALUES
  ('00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0001-000000000001'),
  ('00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0001-000000000002'),
  ('00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0001-000000000003'),
  ('00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0001-000000000004');

-- ────────────────────────────────────────
-- 7. MATCHES (Semifinal bracket)
-- NOTE: referee_id references auth.users. In local seed we use NULL
-- to avoid FK dependency. In staging, replace with real auth user UUIDs.
-- ────────────────────────────────────────

-- Semifinal 1: Felipe Wolf (ELO 1200, Seed 1) vs Carlos Perez (ELO 980, Seed 4)
INSERT INTO matches (id, category_id, entry_a_id, entry_b_id, referee_id, court_id, status, round_name, next_match_id, winner_to_slot)
VALUES
  ('00000000-0000-0000-0003-000000000001',
   '00000000-0000-0000-0000-000000000020',
   '00000000-0000-0000-0002-000000000004',  -- Felipe Wolf
   '00000000-0000-0000-0002-000000000002',  -- Carlos Perez
   NULL,
   'Mesa-1',
   'FINISHED',
   'Semifinal',
   '00000000-0000-0000-0003-000000000003',
   'A'); -- → points to Final (Slot A)

-- Semifinal 2: Andres Rojas (ELO 1150, Seed 2) vs Miguel Torres (ELO 1080, Seed 3)
INSERT INTO matches (id, category_id, entry_a_id, entry_b_id, referee_id, court_id, status, round_name, next_match_id, winner_to_slot)
VALUES
  ('00000000-0000-0000-0003-000000000002',
   '00000000-0000-0000-0000-000000000020',
   '00000000-0000-0000-0002-000000000001',  -- Andres Rojas
   '00000000-0000-0000-0002-000000000003',  -- Miguel Torres
   NULL,
   'Mesa-2',
   'LIVE',
   'Semifinal',
   '00000000-0000-0000-0003-000000000003',
   'B'); -- → points to Final (Slot B)

-- Final (placeholder — winner TBD)
INSERT INTO matches (id, category_id, entry_a_id, entry_b_id, referee_id, court_id, status, round_name)
VALUES
  ('00000000-0000-0000-0003-000000000003',
   '00000000-0000-0000-0000-000000000020',
   NULL,  -- Will be filled by bracket logic when semis finish
   NULL,
   NULL,
   'Mesa-Central',
   'SCHEDULED',
   'Final');

-- ────────────────────────────────────────
-- 8. SCORES & SETS (Relational Data)
-- ────────────────────────────────────────

-- Semifinal 1 base score
INSERT INTO scores (match_id, current_set, points_a, points_b)
VALUES ('00000000-0000-0000-0003-000000000001', 5, 8, 11);

-- Semifinal 1 sets details (Carlos Perez wins 3-2)
INSERT INTO match_sets (match_id, set_number, points_a, points_b, is_finished)
VALUES
  ('00000000-0000-0000-0003-000000000001', 1, 11, 8,  TRUE),
  ('00000000-0000-0000-0003-000000000001', 2, 7,  11, TRUE),
  ('00000000-0000-0000-0003-000000000001', 3, 11, 9,  TRUE),
  ('00000000-0000-0000-0003-000000000001', 4, 6,  11, TRUE),
  ('00000000-0000-0000-0003-000000000001', 5, 8,  11, TRUE);

-- Semifinal 2 base score
INSERT INTO scores (match_id, current_set, points_a, points_b)
VALUES ('00000000-0000-0000-0003-000000000002', 3, 7, 5);

-- Semifinal 2 sets details (Live match)
INSERT INTO match_sets (match_id, set_number, points_a, points_b, is_finished)
VALUES
  ('00000000-0000-0000-0003-000000000002', 1, 11, 8,  TRUE),
  ('00000000-0000-0000-0003-000000000002', 2, 9,  11, TRUE),
  ('00000000-0000-0000-0003-000000000002', 3, 7,  5,  FALSE);

-- ────────────────────────────────────────
-- 9. PAYMENT RECORDS
-- ────────────────────────────────────────
INSERT INTO payments (tournament_entry_id, user_id, provider, provider_txn_id, amount, currency, status)
VALUES
  ('00000000-0000-0000-0002-000000000001', NULL, 'STRIPE', 'pi_test_andres_001', 2500, 'USD', 'SUCCEEDED'),
  ('00000000-0000-0000-0002-000000000002', NULL, 'STRIPE', 'pi_test_carlos_001', 2500, 'USD', 'SUCCEEDED'),
  ('00000000-0000-0000-0002-000000000003', NULL, 'STRIPE', 'pi_test_miguel_001', 2500, 'USD', 'SUCCEEDED'),
  ('00000000-0000-0000-0002-000000000004', NULL, 'STRIPE', 'pi_test_felipe_001', 2500, 'USD', 'SUCCEEDED');

-- ────────────────────────────────────────
-- 10. COMMUNITY FEED (The UPSET event)
-- ────────────────────────────────────────
INSERT INTO community_feed (tournament_id, event_type, payload_json)
VALUES
  ('00000000-0000-0000-0000-000000000010',
   'UPSET',
   '{
     "winner": "Carlos Perez",
     "winner_elo": 980,
     "loser": "Felipe Wolf",
     "loser_elo": 1200,
     "elo_diff": 220,
     "match_id": "00000000-0000-0000-0003-000000000001",
     "round": "Semifinal",
     "sets": "3-2",
     "message": "🔥 UPSET! CP10 (ELO 980) eliminates the top seed FW (ELO 1200) in 5 sets!"
   }'::jsonb);

-- ────────────────────────────────────────
-- SEED COMPLETE
-- Expected state:
--   ✅ 4 players with ELO stats
--   ✅ 1 FINISHED match with UPSET (Carlos over Felipe)
--   ✅ 1 LIVE match (Andres vs Miguel, Set 3)
--   ✅ 1 SCHEDULED final (awaiting bracket logic)
--   ✅ 4 successful payments
--   ✅ 1 community_feed UPSET event
-- ────────────────────────────────────────
