-- Migration: Add sport-specific scoring configs
-- Adds Tennis, Pickleball, Table Tennis with proper scoring rules
-- Updates Padel with sport-specific config

-- Create Tennis sport with proper scoring config
INSERT INTO sports (name, scoring_system, default_points_per_set, default_best_of_sets, scoring_config)
VALUES (
    'Tennis',
    'GAMES',
    4,
    5,
    '{
        "type": "tennis_15_30_40",
        "tournament_format": {
            "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
            "referee_mode": "INTRA_GROUP",
            "loser_referees_winner": true,
            "group_size": { "min": 3, "max": 5 }
        },
        "scoring": {
            "points_per_set": 4,
            "win_margin": 2,
            "best_of_sets": 5
        },
        "game_scoring": {
            "scoring_type": "tennis_15_30_40",
            "points_to_win_game": 4,
            "win_by_two_points": true,
            "games_to_win_set": 6,
            "tiebreak_at": 6,
            "has_tiebreak": true,
            "has_super_tiebreak": false,
            "super_tiebreak_points": null,
            "has_golden_point": false
        }
    }'::jsonb
)
ON CONFLICT (name) DO UPDATE
    SET scoring_config = EXCLUDED.scoring_config,
        scoring_system = EXCLUDED.scoring_system,
        default_points_per_set = EXCLUDED.default_points_per_set,
        default_best_of_sets = EXCLUDED.default_best_of_sets;

-- Create Pickleball sport with proper scoring config
INSERT INTO sports (name, scoring_system, default_points_per_set, default_best_of_sets, scoring_config)
VALUES (
    'Pickleball',
    'POINTS',
    11,
    5,
    '{
        "type": "rally",
        "tournament_format": {
            "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
            "referee_mode": "INTRA_GROUP",
            "loser_referees_winner": true,
            "group_size": { "min": 3, "max": 5 }
        },
        "scoring": {
            "points_per_set": 11,
            "win_margin": 2,
            "best_of_sets": 5
        },
        "game_scoring": {
            "scoring_type": "rally",
            "points_to_win_game": 11,
            "win_by_two_points": true,
            "games_to_win_set": null,
            "tiebreak_at": null,
            "has_tiebreak": false,
            "has_super_tiebreak": false,
            "super_tiebreak_points": null,
            "has_golden_point": false
        }
    }'::jsonb
)
ON CONFLICT (name) DO UPDATE
    SET scoring_config = EXCLUDED.scoring_config,
        scoring_system = EXCLUDED.scoring_system,
        default_points_per_set = EXCLUDED.default_points_per_set,
        default_best_of_sets = EXCLUDED.default_best_of_sets;

-- Create Table Tennis sport with proper scoring config
INSERT INTO sports (name, scoring_system, default_points_per_set, default_best_of_sets, scoring_config)
VALUES (
    'Table Tennis',
    'POINTS',
    11,
    7,
    '{
        "type": "standard",
        "tournament_format": {
            "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
            "referee_mode": "INTRA_GROUP",
            "loser_referees_winner": true,
            "group_size": { "min": 3, "max": 5 }
        },
        "scoring": {
            "points_per_set": 11,
            "win_margin": 2,
            "best_of_sets": 7
        },
        "game_scoring": {
            "scoring_type": "standard",
            "points_to_win_game": 11,
            "win_by_two_points": true,
            "games_to_win_set": null,
            "tiebreak_at": null,
            "has_tiebreak": false,
            "has_super_tiebreak": false,
            "super_tiebreak_points": null,
            "has_golden_point": false,
            "deuce_at": 10
        }
    }'::jsonb
)
ON CONFLICT (name) DO UPDATE
    SET scoring_config = EXCLUDED.scoring_config,
        scoring_system = EXCLUDED.scoring_system,
        default_points_per_set = EXCLUDED.default_points_per_set,
        default_best_of_sets = EXCLUDED.default_best_of_sets;

-- Update Padel with specific scoring config (padel uses golden point)
UPDATE sports
SET scoring_config = '{
    "type": "tennis_15_30_40",
    "tournament_format": {
        "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
        "referee_mode": "INTRA_GROUP",
        "loser_referees_winner": true,
        "group_size": { "min": 3, "max": 5 }
    },
    "scoring": {
        "points_per_set": 4,
        "win_margin": 2,
        "best_of_sets": 5
    },
    "game_scoring": {
        "scoring_type": "tennis_15_30_40",
        "points_to_win_game": 4,
        "win_by_two_points": true,
        "games_to_win_set": 6,
        "tiebreak_at": 6,
        "has_tiebreak": true,
        "has_super_tiebreak": true,
        "super_tiebreak_points": 10,
        "has_golden_point": true
    }
}'::jsonb
WHERE name = 'Padel';

-- Create index for scoring_config queries
CREATE INDEX IF NOT EXISTS idx_sports_scoring_config ON sports(id) WHERE scoring_config IS NOT NULL;

-- Verify sports were created/updated
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM sports WHERE name IN ('Tennis', 'Pickleball', 'Table Tennis', 'Padel');
    RAISE NOTICE 'Sports created/updated: %', v_count;
END $$;