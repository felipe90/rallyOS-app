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
VALUES ('00000000-0000-0000-0003-000000000002', 3, 7, 11);

-- Semifinal 2 sets details (Live match - valid scores)
INSERT INTO match_sets (match_id, set_number, points_a, points_b, is_finished)
VALUES
  ('00000000-0000-0000-0003-000000000002', 1, 11, 8,  TRUE),
  ('00000000-0000-0000-0003-000000000002', 2, 9,  11, TRUE),
  ('00000000-0000-0000-0003-000000000002', 3, 7,  11, FALSE);

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

-- ═══════════════════════════════════════════════════════════════
-- SEED V2: Copa Pádel Medellín 2026 v2
-- Testing Staff & Player-As-Referee System
-- ═══════════════════════════════════════════════════════════════
-- This section adds:
--   - Test users in auth.users
--   - 1 Organizer + 2 External Referees + 16 Players
--   - Club "Club Pádel Medellín"
--   - Tournament "Copa Pádel Medellín 2026 v2" with 2 categories
-- ═══════════════════════════════════════════════════════════════

-- ────────────────────────────────────────
-- V2.1: TEST USERS (for testing auth flows)
-- ────────────────────────────────────────
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT 
    '00000000-0000-0001-0001-000000000001'::uuid,
    'organizer@test.com',
    crypt('TestPassword123!', gen_salt('bf'))::text,
    'authenticated',
    NOW(),
    NOW(),
    NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0001-0001-000000000001'::uuid);

INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0001-0002-000000000001'::uuid, 'referee1@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0001-0002-000000000001'::uuid);

INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0001-0003-000000000001'::uuid, 'referee2@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0001-0003-000000000001'::uuid);

-- Players with auth (8 users)
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0001-000000000001'::uuid, 'carlos@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0001-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0002-000000000001'::uuid, 'miguel@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0002-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0003-000000000001'::uuid, 'luis@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0003-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0004-000000000001'::uuid, 'diego@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0004-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0005-000000000001'::uuid, 'andres@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0005-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0006-000000000001'::uuid, 'fernando@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0006-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0007-000000000001'::uuid, 'javier@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0007-000000000001'::uuid);
INSERT INTO auth.users (id, email, encrypted_password, role, email_confirmed_at, created_at, updated_at)
SELECT '00000000-0000-0002-0008-000000000001'::uuid, 'sergio@test.com', crypt('TestPassword123!', gen_salt('bf'))::text, 'authenticated', NOW(), NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0002-0008-000000000001'::uuid);

-- ────────────────────────────────────────
-- V2.2: PERSONS (Organizer, Referees, Players)
-- ────────────────────────────────────────
-- Organizer
INSERT INTO persons (id, user_id, first_name, last_name, nickname, created_at)
VALUES ('00000000-0000-0001-0000-000000000001', '00000000-0000-0001-0001-000000000001'::uuid, 'Roberto', 'García', 'El Chef', NOW())
ON CONFLICT DO NOTHING;

-- External Referees
INSERT INTO persons (id, user_id, first_name, last_name, nickname, created_at)
VALUES 
    ('00000000-0000-0001-0000-000000000002', '00000000-0000-0001-0002-000000000001'::uuid, 'Jorge', 'López', 'LopezRef', NOW()),
    ('00000000-0000-0001-0000-000000000003', '00000000-0000-0001-0003-000000000001'::uuid, 'Ana', 'Martínez', 'AnaArbiter', NOW())
ON CONFLICT DO NOTHING;

-- Players WITH auth (Primera Category ELO 900-1200)
INSERT INTO persons (id, user_id, first_name, last_name, nickname, created_at)
VALUES
    ('00000000-0000-0002-0000-000000000001', '00000000-0000-0002-0001-000000000001'::uuid, 'Carlos', 'Rodríguez', 'El Pro', NOW()),
    ('00000000-0000-0002-0000-000000000002', '00000000-0000-0002-0002-000000000001'::uuid, 'Miguel', 'Hernández', 'Miggol', NOW()),
    ('00000000-0000-0002-0000-000000000003', '00000000-0000-0002-0003-000000000001'::uuid, 'Luis', 'González', 'LGonz', NOW()),
    ('00000000-0000-0002-0000-000000000004', '00000000-0000-0002-0004-000000000001'::uuid, 'Diego', 'Ramírez', 'Dieguito', NOW()),
    ('00000000-0000-0002-0000-000000000005', '00000000-0000-0002-0005-000000000001'::uuid, 'Andrés', 'Torres', 'El Andy', NOW()),
    ('00000000-0000-0002-0000-000000000006', '00000000-0000-0002-0006-000000000001'::uuid, 'Fernando', 'Flores', 'FerFlores', NOW()),
    ('00000000-0000-0002-0000-000000000007', '00000000-0000-0002-0007-000000000001'::uuid, 'Javier', 'López', 'JaviLpz', NOW()),
    ('00000000-0000-0002-0000-000000000008', '00000000-0000-0002-0008-000000000001'::uuid, 'Sergio', 'Díaz', 'SergyD', NOW())
ON CONFLICT DO NOTHING;

-- Players WITHOUT auth (Shadow Profiles - Segunda Category ELO 600-899)
INSERT INTO persons (id, first_name, last_name, nickname, created_at)
VALUES
    ('00000000-0000-0002-0000-000000000009', 'Pedro', 'Sánchez', 'Pedrin', NOW()),
    ('00000000-0000-0002-0000-000000000010', 'José', 'Martín', 'JoeM', NOW()),
    ('00000000-0000-0002-0000-000000000011', 'Antonio', 'García', 'El Tono', NOW()),
    ('00000000-0000-0002-0000-000000000012', 'Manuel', 'Rodríguez', 'ManuR', NOW()),
    ('00000000-0000-0002-0000-000000000013', 'Francisco', 'Fernández', 'FranFer', NOW()),
    ('00000000-0000-0002-0000-000000000014', 'Alejandro', 'Pérez', 'AlePz', NOW()),
    ('00000000-0000-0002-0000-000000000015', 'David', 'Sánchez', 'DaveS', NOW()),
    ('00000000-0000-0002-0000-000000000016', 'Jorge', 'Gómez', 'Jorgito', NOW())
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────
-- V2.3: ATHLETE STATS
-- ────────────────────────────────────────
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES
    ('00000000-0000-0001-0000-000000000001', '00000000-0000-0000-0000-000000000001', 1050, 50, 0),  -- Organizer
    ('00000000-0000-0001-0000-000000000002', '00000000-0000-0000-0000-000000000001', 1000, 30, 15), -- Referee 1
    ('00000000-0000-0001-0000-000000000003', '00000000-0000-0000-0000-000000000001', 1000, 25, 12)  -- Referee 2
ON CONFLICT DO NOTHING;

-- Primera Category players
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES
    ('00000000-0000-0002-0000-000000000001', '00000000-0000-0000-0000-000000000001', 1180, 45, 0),
    ('00000000-0000-0002-0000-000000000002', '00000000-0000-0000-0000-000000000001', 1120, 38, 0),
    ('00000000-0000-0002-0000-000000000003', '00000000-0000-0000-0000-000000000001', 1080, 32, 0),
    ('00000000-0000-0002-0000-000000000004', '00000000-0000-0000-0000-000000000001', 1040, 28, 0),
    ('00000000-0000-0002-0000-000000000005', '00000000-0000-0000-0000-000000000001', 1000, 25, 0),
    ('00000000-0000-0002-0000-000000000006', '00000000-0000-0000-0000-000000000001', 960, 20, 0),
    ('00000000-0000-0002-0000-000000000007', '00000000-0000-0000-0000-000000000001', 940, 18, 0),
    ('00000000-0000-0002-0000-000000000008', '00000000-0000-0000-0000-000000000001', 920, 15, 0)
ON CONFLICT DO NOTHING;

-- Segunda Category players (Shadow)
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES
    ('00000000-0000-0002-0000-000000000009', '00000000-0000-0000-0000-000000000001', 880, 12, 0),
    ('00000000-0000-0002-0000-000000000010', '00000000-0000-0000-0000-000000000001', 850, 10, 0),
    ('00000000-0000-0002-0000-000000000011', '00000000-0000-0000-0000-000000000001', 820, 8, 0),
    ('00000000-0000-0002-0000-000000000012', '00000000-0000-0000-0000-000000000001', 790, 7, 0),
    ('00000000-0000-0002-0000-000000000013', '00000000-0000-0000-0000-000000000001', 760, 6, 0),
    ('00000000-0000-0002-0000-000000000014', '00000000-0000-0000-0000-000000000001', 730, 5, 0),
    ('00000000-0000-0002-0000-000000000015', '00000000-0000-0000-0000-000000000001', 700, 4, 0),
    ('00000000-0000-0002-0000-000000000016', '00000000-0000-0000-0000-000000000001', 680, 3, 0)
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────
-- V2.4: CLUB
-- ────────────────────────────────────────
INSERT INTO clubs (id, name, country_id, owner_user_id, created_at)
SELECT '00000000-0000-0000-0000-000000000001'::uuid, 'Club Pádel Medellín', c.id, '00000000-0000-0001-0001-000000000001'::uuid, NOW()
FROM countries c WHERE c.iso_code = 'CO'
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────
-- V2.5: TOURNAMENT V2 (Copa Pádel Medellín 2026 v2)
-- ────────────────────────────────────────
INSERT INTO tournaments (id, sport_id, name, status, handicap_enabled, use_differential, created_at)
VALUES ('00000000-0000-0003-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Copa Pádel Medellín 2026 v2', 'DRAFT', TRUE, TRUE, NOW())
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────
-- V2.6: CATEGORIES
-- ────────────────────────────────────────
INSERT INTO categories (id, tournament_id, name, mode, points_override, sets_override, elo_min, elo_max, created_at)
VALUES
    ('00000000-0000-0003-0000-000000000010', '00000000-0000-0003-0000-000000000001', 'Primera Categoría', 'SINGLES', 11, 5, 900, 1200, NOW()),
    ('00000000-0000-0003-0000-000000000011', '00000000-0000-0003-0000-000000000001', 'Segunda Categoría', 'SINGLES', 11, 3, 600, 899, NOW())
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────
-- V2.7: TOURNAMENT STAFF (Organizer + Pending Referees)
-- ────────────────────────────────────────
INSERT INTO tournament_staff (tournament_id, user_id, role, status, invited_by, invite_mode)
VALUES
    ('00000000-0000-0003-0000-000000000001', '00000000-0000-0001-0001-000000000001'::uuid, 'ORGANIZER', 'ACTIVE', NULL, FALSE),
    ('00000000-0000-0003-0000-000000000001', '00000000-0000-0001-0002-000000000001'::uuid, 'EXTERNAL_REFEREE', 'PENDING', '00000000-0000-0001-0001-000000000001'::uuid, TRUE),
    ('00000000-0000-0003-0000-000000000001', '00000000-0000-0001-0003-000000000001'::uuid, 'EXTERNAL_REFEREE', 'PENDING', '00000000-0000-0001-0001-000000000001'::uuid, TRUE)
ON CONFLICT (tournament_id, user_id) DO NOTHING;

-- ────────────────────────────────────────
-- V2.8: TOURNAMENT ENTRIES (16 entries)
-- ────────────────────────────────────────
-- Primera Category (8 players)
INSERT INTO tournament_entries (id, category_id, display_name, current_handicap, status, fee_amount_snap)
VALUES
    ('00000000-0000-0004-0000-000000000001', '00000000-0000-0003-0000-000000000010', 'Carlos Rodríguez', -3, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000002', '00000000-0000-0003-0000-000000000010', 'Miguel Hernández', -2, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000003', '00000000-0000-0003-0000-000000000010', 'Luis González', -1, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000004', '00000000-0000-0003-0000-000000000010', 'Diego Ramírez', 0, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000005', '00000000-0000-0003-0000-000000000010', 'Andrés Torres', 1, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000006', '00000000-0000-0003-0000-000000000010', 'Fernando Flores', 2, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000007', '00000000-0000-0003-0000-000000000010', 'Javier López', 3, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000008', '00000000-0000-0003-0000-000000000010', 'Sergio Díaz', 4, 'CONFIRMED', 2500)
ON CONFLICT DO NOTHING;

-- Segunda Category (8 players)
INSERT INTO tournament_entries (id, category_id, display_name, current_handicap, status, fee_amount_snap)
VALUES
    ('00000000-0000-0004-0000-000000000009', '00000000-0000-0003-0000-000000000011', 'Pedro Sánchez', 5, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000010', '00000000-0000-0003-0000-000000000011', 'José Martín', 6, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000011', '00000000-0000-0003-0000-000000000011', 'Antonio García', 7, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000012', '00000000-0000-0003-0000-000000000011', 'Manuel Rodríguez', 8, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000013', '00000000-0000-0003-0000-000000000011', 'Francisco Fernández', 9, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000014', '00000000-0000-0003-0000-000000000011', 'Alejandro Pérez', 10, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000015', '00000000-0000-0003-0000-000000000011', 'David Sánchez', 11, 'CONFIRMED', 2500),
    ('00000000-0000-0004-0000-000000000016', '00000000-0000-0003-0000-000000000011', 'Jorge Gómez', 12, 'CONFIRMED', 2500)
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────
-- V2.9: ENTRY MEMBERS
-- ────────────────────────────────────────
-- Primera Category Members
INSERT INTO entry_members (entry_id, person_id) VALUES
    ('00000000-0000-0004-0000-000000000001', '00000000-0000-0002-0000-000000000001'),
    ('00000000-0000-0004-0000-000000000002', '00000000-0000-0002-0000-000000000002'),
    ('00000000-0000-0004-0000-000000000003', '00000000-0000-0002-0000-000000000003'),
    ('00000000-0000-0004-0000-000000000004', '00000000-0000-0002-0000-000000000004'),
    ('00000000-0000-0004-0000-000000000005', '00000000-0000-0002-0000-000000000005'),
    ('00000000-0000-0004-0000-000000000006', '00000000-0000-0002-0000-000000000006'),
    ('00000000-0000-0004-0000-000000000007', '00000000-0000-0002-0000-000000000007'),
    ('00000000-0000-0004-0000-000000000008', '00000000-0000-0002-0000-000000000008')
ON CONFLICT DO NOTHING;

-- Segunda Category Members
INSERT INTO entry_members (entry_id, person_id) VALUES
    ('00000000-0000-0004-0000-000000000009', '00000000-0000-0002-0000-000000000009'),
    ('00000000-0000-0004-0000-000000000010', '00000000-0000-0002-0000-000000000010'),
    ('00000000-0000-0004-0000-000000000011', '00000000-0000-0002-0000-000000000011'),
    ('00000000-0000-0004-0000-000000000012', '00000000-0000-0002-0000-000000000012'),
    ('00000000-0000-0004-0000-000000000013', '00000000-0000-0002-0000-000000000013'),
    ('00000000-0000-0004-0000-000000000014', '00000000-0000-0002-0000-000000000014'),
    ('00000000-0000-0004-0000-000000000015', '00000000-0000-0002-0000-000000000015'),
    ('00000000-0000-0004-0000-000000000016', '00000000-0000-0002-0000-000000000016')
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- V2 SEED COMPLETE
-- Expected state:
--   ✅ 1 Organizer (organizer@test.com)
--   ✅ 2 External Referees (PENDING invitation)
--   ✅ 8 Players with auth (for player-as-referee testing)
--   ✅ 8 Shadow Profiles (no auth)
--   ✅ 1 Club
--   ✅ 1 Tournament (DRAFT) with 2 categories
--   ✅ 16 entries (8 per category)
-- ═══════════════════════════════════════════════════════════════
