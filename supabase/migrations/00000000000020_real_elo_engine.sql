-- ============================================================
-- Migration: 00000000000020_real_elo_engine
-- Purpose: 
--   Implement professional ELO calculation logic linked to match_sets.
-- ============================================================

CREATE OR REPLACE FUNCTION process_match_completion()
RETURNS TRIGGER
SECURITY DEFINER
AS $$
DECLARE
    v_entry_a_id UUID;
    v_entry_b_id UUID;
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
    v_sets_a INTEGER;
    v_sets_b INTEGER;
BEGIN
    -- Only trigger on status change to FINISHED
    IF NEW.status = 'FINISHED' AND (OLD.status IS NULL OR OLD.status != 'FINISHED') THEN

        -- Get entry IDs and sport
        SELECT m.entry_a_id, m.entry_b_id, t.sport_id
        INTO v_entry_a_id, v_entry_b_id, v_sport_id
        FROM matches m
        JOIN categories c ON m.category_id = c.id
        JOIN tournaments t ON c.tournament_id = t.id
        WHERE m.id = NEW.id;

        -- Skip if missing required data
        IF v_entry_a_id IS NULL OR v_entry_b_id IS NULL OR v_sport_id IS NULL THEN
            RETURN NEW;
        END IF;

        -- DETERMINE WINNER FROM match_sets
        SELECT 
            COUNT(*) FILTER (WHERE points_a > points_b),
            COUNT(*) FILTER (WHERE points_b > points_a)
        INTO v_sets_a, v_sets_b
        FROM match_sets
        WHERE match_id = NEW.id;

        IF v_sets_a > v_sets_b THEN
            v_winner_person_id := (SELECT person_id FROM entry_members WHERE entry_id = v_entry_a_id LIMIT 1);
            v_loser_person_id := (SELECT person_id FROM entry_members WHERE entry_id = v_entry_b_id LIMIT 1);
        ELSIF v_sets_b > v_sets_a THEN
            v_winner_person_id := (SELECT person_id FROM entry_members WHERE entry_id = v_entry_b_id LIMIT 1);
            v_loser_person_id := (SELECT person_id FROM entry_members WHERE entry_id = v_entry_a_id LIMIT 1);
        ELSE
            -- Tie? (Rare in Padel, but theoretically possible if suspended or manual draw)
            RETURN NEW;
        END IF;

        -- Get current ELO and match counts
        SELECT COALESCE(current_elo, 1000), COALESCE(matches_played, 0)
        INTO v_winner_elo, v_winner_matches
        FROM athlete_stats
        WHERE person_id = v_winner_person_id AND sport_id = v_sport_id;

        SELECT COALESCE(current_elo, 1000), COALESCE(matches_played, 0)
        INTO v_loser_elo, v_loser_matches
        FROM athlete_stats
        WHERE person_id = v_loser_person_id AND sport_id = v_sport_id;

        -- Calculate K-factors
        v_k_factor_winner := CASE
            WHEN v_winner_matches < 30 THEN 32
            WHEN v_winner_matches < 100 THEN 24
            ELSE 16
        END;

        -- Expected score for winner (Standard ELO)
        v_expected_winner := 1.0 / (1.0 + POWER(10, (v_loser_elo - v_winner_elo)::NUMERIC / 400.0));

        -- ELO change
        v_elo_change := ROUND(v_k_factor_winner * (1 - v_expected_winner))::INTEGER;
        
        -- Minimum move
        IF v_elo_change = 0 AND v_winner_elo != v_loser_elo THEN
            v_elo_change := 1;
        END IF;

        -- LOG HISTORY
        INSERT INTO elo_history (person_id, sport_id, match_id, previous_elo, new_elo, elo_change, change_type)
        VALUES (v_winner_person_id, v_sport_id, NEW.id, v_winner_elo, v_winner_elo + v_elo_change, v_elo_change, 'MATCH_WIN');

        INSERT INTO elo_history (person_id, sport_id, match_id, previous_elo, new_elo, elo_change, change_type)
        VALUES (v_loser_person_id, v_sport_id, NEW.id, v_loser_elo, v_loser_elo - v_elo_change, -v_elo_change, 'MATCH_LOSS');

        -- UPDATE STATS
        INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played)
        VALUES (v_winner_person_id, v_sport_id, v_winner_elo + v_elo_change, v_winner_matches + 1)
        ON CONFLICT (person_id, sport_id) DO UPDATE SET
            current_elo = EXCLUDED.current_elo,
            matches_played = EXCLUDED.matches_played;

        INSERT INTO athlete_stats (person_id, sport_id, current_elo, matches_played)
        VALUES (v_loser_person_id, v_sport_id, v_loser_elo - v_elo_change, v_loser_matches + 1)
        ON CONFLICT (person_id, sport_id) DO UPDATE SET
            current_elo = EXCLUDED.current_elo,
            matches_played = EXCLUDED.matches_played;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-attach trigger
DROP TRIGGER IF EXISTS trg_match_completion ON matches;
CREATE TRIGGER trg_match_completion
AFTER UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION process_match_completion();
