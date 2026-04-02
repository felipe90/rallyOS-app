-- ============================================================
-- Migration: 00000000000035_seed_sports_with_scoring_config
-- Purpose: Add 4 sports with complete scoring_config
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Tennis - scoring system 15-30-40, tiebreak at 6-6
-- ═══════════════════════════════════════════════════════════════
INSERT INTO sports (id, name, scoring_system, default_points_per_set, default_best_of_sets, scoring_config)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    'Tennis',
    'GAMES',
    4,
    3,
    '{
        "type": "tennis_15_30_40",
        "points_per_set": 4,
        "best_of_sets": 3,
        "win_by_2": true,
        "win_by_2_games": true,
        "games_to_win_set": 6,
        "tie_break": {
            "enabled": true,
            "at": 6,
            "points": 7
        },
        "has_super_tiebreak": false,
        "super_tiebreak_points": 10,
        "scoring_system": "games",
        "tennis_scoring": true,
        "min_difference": 2
    }'::jsonb
)
ON CONFLICT (name) DO UPDATE SET
    scoring_config = EXCLUDED.scoring_config;

-- ═══════════════════════════════════════════════════════════════
-- Pickleball - rally scoring, 11 points, win by 2
-- ═══════════════════════════════════════════════════════════════
INSERT INTO sports (id, name, scoring_system, default_points_per_set, default_best_of_sets, scoring_config)
VALUES (
    '00000000-0000-0000-0000-000000000003',
    'Pickleball',
    'POINTS',
    11,
    5,
    '{
        "type": "rally",
        "points_per_set": 11,
        "best_of_sets": 5,
        "win_by_2": true,
        "win_by_2_games": false,
        "games_to_win_set": 1,
        "tie_break": {
            "enabled": false,
            "at": null,
            "points": null
        },
        "has_super_tiebreak": false,
        "super_tiebreak_points": null,
        "scoring_system": "points",
        "rally_scoring": true,
        "min_difference": 2
    }'::jsonb
)
ON CONFLICT (name) DO UPDATE SET
    scoring_config = EXCLUDED.scoring_config;

-- ═══════════════════════════════════════════════════════════════
-- Table Tennis - 11 points, win by 2, no tiebreak, deuce at 10-10
-- ═══════════════════════════════════════════════════════════════
INSERT INTO sports (id, name, scoring_system, default_points_per_set, default_best_of_sets, scoring_config)
VALUES (
    '00000000-0000-0000-0000-000000000004',
    'Table Tennis',
    'POINTS',
    11,
    5,
    '{
        "type": "standard",
        "points_per_set": 11,
        "best_of_sets": 5,
        "win_by_2": true,
        "win_by_2_games": false,
        "games_to_win_set": 1,
        "tie_break": {
            "enabled": false,
            "at": null,
            "points": null
        },
        "has_super_tiebreak": false,
        "super_tiebreak_points": null,
        "scoring_system": "points",
        "rally_scoring": true,
        "deuce_at": 10,
        "min_difference": 2
    }'::jsonb
)
ON CONFLICT (name) DO UPDATE SET
    scoring_config = EXCLUDED.scoring_config;

-- ═══════════════════════════════════════════════════════════════
-- Padel - already exists, update with scoring_config (from seed v2)
-- ═══════════════════════════════════════════════════════════════
UPDATE sports SET
    scoring_config = '{
        "type": "tennis_15_30_40",
        "points_per_set": 4,
        "best_of_sets": 5,
        "win_by_2": true,
        "win_by_2_games": true,
        "games_to_win_set": 6,
        "tie_break": {
            "enabled": true,
            "at": 6,
            "points": 7
        },
        "has_super_tiebreak": true,
        "super_tiebreak_points": 10,
        "scoring_system": "games",
        "golden_point": {
            "enabled": true,
            "at": 40
        },
        "min_difference": 2
    }'::jsonb
WHERE name = 'Padel';

-- Verify all 4 sports have scoring_config
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM sports WHERE scoring_config IS NOT NULL) >= 4, 'Should have at least 4 sports with scoring_config';
END $$;

COMMENT ON COLUMN sports.scoring_config IS 
'JSONB containing sport-specific scoring rules:
- type: scoring type (standard, rally, tennis_15_30_40)
- points_per_set: points needed to win a game
- best_of_sets: number of sets in a match
- win_by_2: require 2 point lead to win
- win_by_2_games: require 2 game lead to win set
- games_to_win_set: games needed to win a set
- tie_break: {enabled, at, points}
- has_super_tiebreak: whether super tiebreak is used
- super_tiebreak_points: points for super tiebreak
- golden_point: {enabled, at} for Padel
- deuce_at: deuce threshold for TT';

COMMIT;
