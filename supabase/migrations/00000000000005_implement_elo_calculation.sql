-- ============================================
-- rallyOS: ELO Calculation Trigger
-- ============================================
-- Implements standard ELO calculation when matches complete
-- K-Factor: 32 (<30 matches), 24 (30-100), 16 (>100)

-- ============================================
-- 1. CREATE ELO CALCULATION FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION process_match_completion()
RETURNS TRIGGER
SECURITY DEFINER
AS $$
DECLARE
    v_entry_a_uuid UUID;
    v_entry_b_uuid UUID;
    v_winner_person_id UUID;
    v_loser_person_id UUID;
    v_sport_id UUID;
    v_winner_elo INTEGER;
    v_loser_elo INTEGER;
    v_winner_matches INTEGER;
    v_loser_matches INTEGER;
    v_expected_winner NUMERIC;
    v_k_factor_winner INTEGER;
    v_k_factor_loser INTEGER;
    v_elo_change INTEGER;
BEGIN
    -- Only trigger on status change to FINISHED
    IF NEW.status = 'FINISHED' AND (OLD.status IS NULL OR OLD.status != 'FINISHED') THEN

        -- Get entry IDs and sport (sport_id comes from tournament via category)
        SELECT m.entry_a_id, m.entry_b_id, t.sport_id
        INTO v_entry_a_uuid, v_entry_b_uuid, v_sport_id
        FROM matches m
        JOIN categories c ON m.category_id = c.id
        JOIN tournaments t ON c.tournament_id = t.id
        WHERE m.id = NEW.id;

        -- Skip if missing required data
        IF v_entry_a_uuid IS NULL OR v_entry_b_uuid IS NULL OR v_sport_id IS NULL THEN
            RETURN NEW;
        END IF;

        -- Determine winner (simplified: Entry A wins)
        v_winner_person_id := (SELECT person_id FROM entry_members WHERE entry_id = v_entry_a_uuid LIMIT 1);
        v_loser_person_id := (SELECT person_id FROM entry_members WHERE entry_id = v_entry_b_uuid LIMIT 1);

        -- Skip if missing player data
        IF v_winner_person_id IS NULL OR v_loser_person_id IS NULL THEN
            RETURN NEW;
        END IF;

        -- Get current ELO and match counts (default to 1000/0 if no stats exist)
        SELECT COALESCE(current_elo, 1000), COALESCE(matches_played, 0)
        INTO v_winner_elo, v_winner_matches
        FROM athlete_stats
        WHERE person_id = v_winner_person_id AND sport_id = v_sport_id;

        SELECT COALESCE(current_elo, 1000), COALESCE(matches_played, 0)
        INTO v_loser_elo, v_loser_matches
        FROM athlete_stats
        WHERE person_id = v_loser_person_id AND sport_id = v_sport_id;

        -- Default ELOs if still NULL
        v_winner_elo := COALESCE(v_winner_elo, 1000);
        v_winner_matches := COALESCE(v_winner_matches, 0);
        v_loser_elo := COALESCE(v_loser_elo, 1000);
        v_loser_matches := COALESCE(v_loser_matches, 0);

        -- Calculate K-factors
        v_k_factor_winner := CASE
            WHEN v_winner_matches < 30 THEN 32
            WHEN v_winner_matches < 100 THEN 24
            ELSE 16
        END;

        v_k_factor_loser := CASE
            WHEN v_loser_matches < 30 THEN 32
            WHEN v_loser_matches < 100 THEN 24
            ELSE 16
        END;

        -- Calculate expected score for winner
        -- Use POWER() for exponential calculation
        v_expected_winner := 1.0 / (1.0 + POWER(10, (v_loser_elo - v_winner_elo)::NUMERIC / 400.0));

        -- ELO change (winner gets +K * (1 - expected), loser gets -K * (0 - expected))
        v_elo_change := ROUND(v_k_factor_winner * (1 - v_expected_winner))::INTEGER;

        -- Ensure minimum change of 1 point (unless ratings are identical)
        IF v_elo_change = 0 AND v_winner_elo != v_loser_elo THEN
            v_elo_change := 1;
        END IF;

        -- Record winner ELO history
        INSERT INTO elo_history (person_id, sport_id, match_id, previous_elo, new_elo, elo_change, change_type)
        VALUES (v_winner_person_id, v_sport_id, NEW.id, v_winner_elo, v_winner_elo + v_elo_change, v_elo_change, 'MATCH_WIN');

        -- Record loser ELO history
        INSERT INTO elo_history (person_id, sport_id, match_id, previous_elo, new_elo, elo_change, change_type)
        VALUES (v_loser_person_id, v_sport_id, NEW.id, v_loser_elo, v_loser_elo - v_elo_change, -v_elo_change, 'MATCH_LOSS');

        -- Update or insert winner stats
        INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played)
        VALUES (v_winner_person_id, v_sport_id, v_winner_elo + v_elo_change, v_winner_matches + 1)
        ON CONFLICT (person_id, sport_id) DO UPDATE SET
            current_elo = athlete_stats.current_elo + v_elo_change,
            matches_played = athlete_stats.matches_played + 1;

        -- Update or insert loser stats
        INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played)
        VALUES (v_loser_person_id, v_sport_id, v_loser_elo - v_elo_change, v_loser_matches + 1)
        ON CONFLICT (person_id, sport_id) DO UPDATE SET
            current_elo = athlete_stats.current_elo - v_elo_change,
            matches_played = athlete_stats.matches_played + 1;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. CREATE TRIGGER ON MATCHES TABLE
-- ============================================
DROP TRIGGER IF EXISTS trg_match_completion ON matches;

CREATE TRIGGER trg_match_completion
AFTER UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION process_match_completion();
