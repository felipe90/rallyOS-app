-- ============================================================
-- RALLYOS: SEED V2 — Copa Pádel Medellín 2026 v2
-- Scenario: Testing Staff & Player-As-Referee System
-- ============================================================
-- This seed creates:
--   - 1 Organizer (with auth)
--   - 2 External Referees (with auth)
--   - 16 Players (8 with auth, 8 shadow profiles)
--   - 2 Categories (Primera: ELO 900-1200, Segunda: ELO 600-899)
--   - 1 Tournament in DRAFT status ready for E2E testing
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- PHASE 1: Ensure Padel sport exists
-- ═══════════════════════════════════════════════════════════════
INSERT INTO sports (id, name, scoring_system, default_points_per_set, default_best_of_sets)
VALUES ('00000000-0000-0000-0000-000000000001', 'Padel', 'POINTS', 11, 5)
ON CONFLICT (name) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- PHASE 2: Create Club
-- ═══════════════════════════════════════════════════════════════
INSERT INTO clubs (id, name, country_id, owner_user_id, created_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'Club Pádel Medellín', 'COL', NULL, NOW())
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- PHASE 3: Create ORGANIZER (with auth.users)
-- ═══════════════════════════════════════════════════════════════
-- Note: In real Supabase, this would be done via sign-up
-- For testing, we'll create the person and link later
INSERT INTO persons (id, user_id, first_name, last_name, nickname, created_at)
VALUES (
    '00000000-0000-0001-0000-000000000001',
    '00000000-0000-0001-0001-000000000001', -- This would be the auth.users id
    'Roberto',
    'García',
    'El Chef',
    NOW()
);

-- Create athlete stats for organizer (so they can be invited as referee too)
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES ('00000000-0000-0001-0000-000000000001', '00000000-0000-0000-0000-000000000001', 1050, 50, 0);

-- ═══════════════════════════════════════════════════════════════
-- PHASE 4: Create 2 EXTERNAL REFEREES (with auth.users)
-- ═══════════════════════════════════════════════════════════════
INSERT INTO persons (id, user_id, first_name, last_name, nickname, created_at)
VALUES
    ('00000000-0000-0001-0000-000000000002', '00000000-0000-0001-0002-000000000001', 'Jorge', 'López', 'LopezRef', NOW()),
    ('00000000-0000-0001-0000-000000000003', '00000000-0000-0001-0003-000000000001', 'Ana', 'Martínez', 'AnaArbiter', NOW());

INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES
    ('00000000-0000-0001-0000-000000000002', '00000000-0000-0000-0000-000000000001', 1000, 30, 15),
    ('00000000-0000-0001-0000-000000000003', '00000000-0000-0000-0000-000000000001', 1000, 25, 12);

-- ═══════════════════════════════════════════════════════════════
-- PHASE 5: Create 16 PLAYERS (8 with auth, 8 shadow)
-- ═══════════════════════════════════════════════════════════════

-- Players WITH auth.users (for testing full flow)
INSERT INTO persons (id, user_id, first_name, last_name, nickname, created_at)
VALUES
    -- Primera Category (ELO 900-1200)
    ('00000000-0000-0002-0000-000000000001', '00000000-0000-0002-0001-000000000001', 'Carlos', 'Rodríguez', 'El Pro', NOW()),
    ('00000000-0000-0002-0000-000000000002', '00000000-0000-0002-0002-000000000001', 'Miguel', 'Hernández', 'Miggol', NOW()),
    ('00000000-0000-0002-0000-000000000003', '00000000-0000-0002-0003-000000000001', 'Luis', 'González', 'LGonz', NOW()),
    ('00000000-0000-0002-0000-000000000004', '00000000-0000-0002-0004-000000000001', 'Diego', 'Ramírez', 'Dieguito', NOW()),
    ('00000000-0000-0002-0000-000000000005', '00000000-0000-0002-0005-000000000001', 'Andrés', 'Torres', 'El Andy', NOW()),
    ('00000000-0000-0002-0000-000000000006', '00000000-0000-0002-0006-000000000001', 'Fernando', 'Flores', 'FerFlores', NOW()),
    ('00000000-0000-0002-0000-000000000007', '00000000-0000-0002-0007-000000000001', 'Javier', 'López', 'JaviLpz', NOW()),
    ('00000000-0000-0002-0000-000000000008', '00000000-0000-0002-0008-000000000001', 'Sergio', 'Díaz', 'SergyD', NOW());

-- Players WITHOUT auth.users (shadow profiles)
INSERT INTO persons (id, first_name, last_name, nickname, created_at)
VALUES
    -- Segunda Category (ELO 600-899)
    ('00000000-0000-0002-0000-000000000009', 'Pedro', 'Sánchez', 'Pedrin', NOW()),
    ('00000000-0000-0002-0000-000000000010', 'José', 'Martín', 'JoeM', NOW()),
    ('00000000-0000-0002-0000-000000000011', 'Antonio', 'García', 'El Tono', NOW()),
    ('00000000-0000-0002-0000-000000000012', 'Manuel', 'Rodríguez', 'ManuR', NOW()),
    ('00000000-0000-0002-0000-000000000013', 'Francisco', 'Fernández', 'FranFer', NOW()),
    ('00000000-0000-0002-0000-000000000014', 'Alejandro', 'Pérez', 'AlePz', NOW()),
    ('00000000-0000-0002-0000-000000000015', 'David', 'Sánchez', 'DaveS', NOW()),
    ('00000000-0000-0002-0000-000000000016', 'Jorge', 'Gómez', 'Jorgito', NOW());

-- ═══════════════════════════════════════════════════════════════
-- PHASE 6: Create Athlete Stats
-- ═══════════════════════════════════════════════════════════════

-- Primera Category players (ELO 900-1200)
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES
    ('00000000-0000-0002-0000-000000000001', '00000000-0000-0000-0000-000000000001', 1180, 45, 0), -- Carlos
    ('00000000-0000-0002-0000-000000000002', '00000000-0000-0000-0000-000000000001', 1120, 38, 0), -- Miguel
    ('00000000-0000-0002-0000-000000000003', '00000000-0000-0000-0000-000000000001', 1080, 32, 0), -- Luis
    ('00000000-0000-0002-0000-000000000004', '00000000-0000-0000-0000-000000000001', 1040, 28, 0), -- Diego
    ('00000000-0000-0002-0000-000000000005', '00000000-0000-0000-0000-000000000001', 1000, 25, 0), -- Andrés
    ('00000000-0000-0002-0000-000000000006', '00000000-0000-0000-0000-000000000001', 960, 20, 0),  -- Fernando
    ('00000000-0000-0002-0000-000000000007', '00000000-0000-0000-0000-000000000001', 940, 18, 0),  -- Javier
    ('00000000-0000-0002-0000-000000000008', '00000000-0000-0000-0000-000000000001', 920, 15, 0);  -- Sergio

-- Segunda Category players (ELO 600-899)
INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played, matches_refereed)
VALUES
    ('00000000-0000-0002-0000-000000000009', '00000000-0000-0000-0000-000000000001', 880, 12, 0),  -- Pedro
    ('00000000-0000-0002-0000-000000000010', '00000000-0000-0000-0000-000000000001', 850, 10, 0),  -- José
    ('00000000-0000-0002-0000-000000000011', '00000000-0000-0000-0000-000000000001', 820, 8, 0),   -- Antonio
    ('00000000-0000-0002-0000-000000000012', '00000000-0000-0000-0000-000000000001', 790, 7, 0),   -- Manuel
    ('00000000-0000-0002-0000-000000000013', '00000000-0000-0000-0000-000000000001', 760, 6, 0),   -- Francisco
    ('00000000-0000-0002-0000-000000000014', '00000000-0000-0000-0000-000000000001', 730, 5, 0),   -- Alejandro
    ('00000000-0000-0002-0000-000000000015', '00000000-0000-0000-0000-000000000001', 700, 4, 0),   -- David
    ('00000000-0000-0002-0000-000000000016', '00000000-0000-0000-0000-000000000001', 680, 3, 0);  -- Jorge

-- ═══════════════════════════════════════════════════════════════
-- PHASE 7: Create Tournament
-- ═══════════════════════════════════════════════════════════════
INSERT INTO tournaments (id, sport_id, name, status, handicap_enabled, use_differential, club_id, created_at)
VALUES (
    '00000000-0000-0003-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Copa Pádel Medellín 2026 v2',
    'DRAFT',
    TRUE,
    TRUE,
    '00000000-0000-0000-0000-000000000001',
    NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- PHASE 8: Create Categories
-- ═══════════════════════════════════════════════════════════════
INSERT INTO categories (id, tournament_id, name, mode, points_override, sets_override, elo_min, elo_max, created_at)
VALUES
    ('00000000-0000-0003-0000-000000000010', '00000000-0000-0003-0000-000000000001', 'Primera Categoría', 'SINGLES', 11, 5, 900, 1200, NOW()),
    ('00000000-0000-0003-0000-000000000011', '00000000-0000-0003-0000-000000000001', 'Segunda Categoría', 'SINGLES', 11, 3, 600, 899, NOW());

-- ═══════════════════════════════════════════════════════════════
-- PHASE 9: Create Tournament Staff
-- ═══════════════════════════════════════════════════════════════

-- Organizer (will be created automatically by trigger, but let's ensure it's set)
INSERT INTO tournament_staff (tournament_id, user_id, role, status, invited_by, invite_mode)
VALUES (
    '00000000-0000-0003-0000-000000000001',
    '00000000-0000-0001-0001-000000000001',
    'ORGANIZER',
    'ACTIVE',
    NULL,
    FALSE
) ON CONFLICT (tournament_id, user_id) DO NOTHING;

-- External Referees (pre-invited, status PENDING for testing accept flow)
INSERT INTO tournament_staff (tournament_id, user_id, role, status, invited_by, invite_mode, expires_at)
VALUES
    ('00000000-0000-0003-0000-000000000001', '00000000-0000-0001-0002-000000000001', 'EXTERNAL_REFEREE', 'PENDING', '00000000-0000-0001-0001-000000000001', TRUE, NOW() + INTERVAL '7 days'),
    ('00000000-0000-0003-0000-000000000001', '00000000-0000-0001-0003-000000000001', 'EXTERNAL_REFEREE', 'PENDING', '00000000-0000-0001-0001-000000000001', TRUE, NOW() + INTERVAL '7 days');

-- ═══════════════════════════════════════════════════════════════
-- PHASE 10: Create Tournament Entries + Entry Members
-- ═══════════════════════════════════════════════════════════════

-- Primera Category Entries (8 players)
INSERT INTO tournament_entries (id, category_id, display_name, current_handicap, status, checked_in_at)
VALUES
    ('00000000-0000-0004-0000-000000000001', '00000000-0000-0003-0000-000000000010', 'Carlos Rodríguez', -3, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000002', '00000000-0000-0003-0000-000000000010', 'Miguel Hernández', -2, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000003', '00000000-0000-0003-0000-000000000010', 'Luis González', -1, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000004', '00000000-0000-0003-0000-000000000010', 'Diego Ramírez', 0, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000005', '00000000-0000-0003-0000-000000000010', 'Andrés Torres', 1, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000006', '00000000-0000-0003-0000-000000000010', 'Fernando Flores', 2, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000007', '00000000-0000-0003-0000-000000000010', 'Javier López', 3, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000008', '00000000-0000-0003-0000-000000000010', 'Sergio Díaz', 4, 'CONFIRMED', NULL);

-- Segunda Category Entries (8 players)
INSERT INTO tournament_entries (id, category_id, display_name, current_handicap, status, checked_in_at)
VALUES
    ('00000000-0000-0004-0000-000000000009', '00000000-0000-0003-0000-000000000011', 'Pedro Sánchez', 5, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000010', '00000000-0000-0003-0000-000000000011', 'José Martín', 6, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000011', '00000000-0000-0003-0000-000000000011', 'Antonio García', 7, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000012', '00000000-0000-0003-0000-000000000011', 'Manuel Rodríguez', 8, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000013', '00000000-0000-0003-0000-000000000011', 'Francisco Fernández', 9, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000014', '00000000-0000-0003-0000-000000000011', 'Alejandro Pérez', 10, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000015', '00000000-0000-0003-0000-000000000011', 'David Sánchez', 11, 'CONFIRMED', NULL),
    ('00000000-0000-0004-0000-000000000016', '00000000-0000-0003-0000-000000000011', 'Jorge Gómez', 12, 'CONFIRMED', NULL);

-- ═══════════════════════════════════════════════════════════════
-- PHASE 11: Link Entries to Persons (Entry Members)
-- ═══════════════════════════════════════════════════════════════

-- Primera Category Members
INSERT INTO entry_members (entry_id, person_id)
VALUES
    ('00000000-0000-0004-0000-000000000001', '00000000-0000-0002-0000-000000000001'), -- Carlos
    ('00000000-0000-0004-0000-000000000002', '00000000-0000-0002-0000-000000000002'), -- Miguel
    ('00000000-0000-0004-0000-000000000003', '00000000-0000-0002-0000-000000000003'), -- Luis
    ('00000000-0000-0004-0000-000000000004', '00000000-0000-0002-0000-000000000004'), -- Diego
    ('00000000-0000-0004-0000-000000000005', '00000000-0000-0002-0000-000000000005'), -- Andrés
    ('00000000-0000-0004-0000-000000000006', '00000000-0000-0002-0000-000000000006'), -- Fernando
    ('00000000-0000-0004-0000-000000000007', '00000000-0000-0002-0000-000000000007'), -- Javier
    ('00000000-0000-0004-0000-000000000008', '00000000-0000-0002-0000-000000000008'); -- Sergio

-- Segunda Category Members
INSERT INTO entry_members (entry_id, person_id)
VALUES
    ('00000000-0000-0004-0000-000000000009', '00000000-0000-0002-0000-000000000009'), -- Pedro
    ('00000000-0000-0004-0000-000000000010', '00000000-0000-0002-0000-000000000010'), -- José
    ('00000000-0000-0004-0000-000000000011', '00000000-0000-0002-0000-000000000011'), -- Antonio
    ('00000000-0000-0004-0000-000000000012', '00000000-0000-0002-0000-000000000012'), -- Manuel
    ('00000000-0000-0004-0000-000000000013', '00000000-0000-0002-0000-000000000013'), -- Francisco
    ('00000000-0000-0004-0000-000000000014', '00000000-0000-0002-0000-000000000014'), -- Alejandro
    ('00000000-0000-0004-0000-000000000015', '00000000-0000-0002-0000-000000000015'), -- David
    ('00000000-0000-0004-0000-000000000016', '00000000-0000-0002-0000-000000000016'); -- Jorge

-- ═══════════════════════════════════════════════════════════════
-- SEED SUMMARY
-- ═══════════════════════════════════════════════════════════════

-- Expected state after seed:
--   ✅ 1 Sport: Padel
--   ✅ 1 Club: Club Pádel Medellín
--   ✅ 1 Organizer (with auth) - El Chef
--   ✅ 2 External Referees (with auth) - PENDING invitation
--   ✅ 16 Players (8 with auth + 8 shadow profiles)
--   ✅ 16 Athlete Stats with varied ELOs
--   ✅ 1 Tournament (DRAFT status)
--   ✅ 2 Categories (Primera: 900-1200, Segunda: 600-899)
--   ✅ 16 Tournament Entries (8 per category)
--   ✅ 16 Entry Members linked to persons

-- To test the full flow:
--   1. Accept the 2 referee invitations (accept_invitation)
--   2. Change tournament status to CHECK_IN
--   3. Perform check-in for all entries
--   4. Players toggle_referee_volunteer(true)
--   5. Generate brackets (generate_bracket)
--   6. Generate suggestions (generate_referee_suggestions)
--   7. Confirm assignments (confirm_referee_assignment)
--   8. Start matches, enter scores, etc.

COMMIT;
