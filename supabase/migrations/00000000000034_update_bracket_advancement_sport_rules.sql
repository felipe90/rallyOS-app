-- ============================================================
-- Migration: 00000000000034_update_bracket_advancement_sport_rules
-- Purpose: Update bracket advancement to use sport-specific rules
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Update advance_bracket_winner() to use calculate_set_winner()
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION advance_bracket_winner()
RETURNS TRIGGER
SECURITY DEFINER
AS $$
DECLARE
    v_winner_entry_id UUID;
    v_next_match_id UUID;
    v_next_entry_a UUID;
    v_next_entry_b UUID;
    v_entry_a_sets INTEGER;
    v_entry_b_sets INTEGER;
    v_points_a INTEGER;
    v_points_b INTEGER;
    v_scoring_config JSONB;
    v_winner CHAR(1);
BEGIN
    -- Only trigger when match becomes FINISHED
    IF NEW.status = 'FINISHED' AND OLD.status != 'FINISHED' THEN
        
        -- Get current score from scores table (not sets_json - that column doesn't exist)
        SELECT COALESCE(s.points_a, 0), COALESCE(s.points_b, 0)
        INTO v_points_a, v_points_b
        FROM scores s
        WHERE s.match_id = NEW.id;
        
        -- Try to get sport-specific scoring config
        BEGIN
            SELECT COALESCE(sp.scoring_config, 
                jsonb_build_object(
                    'points_per_set', COALESCE(sp.default_points_per_set, 11),
                    'win_by_2', true,
                    'tie_break', jsonb_build_object('enabled', true, 'points', 7),
                    'games_to_win_set', 6,
                    'tiebreak_at', 6
                )
            ) INTO v_scoring_config
            FROM matches m
            JOIN categories c ON m.category_id = c.id
            JOIN tournaments t ON c.tournament_id = t.id
            JOIN sports sp ON t.sport_id = sp.id
            WHERE m.id = NEW.id;
        EXCEPTION WHEN OTHERS THEN
            v_scoring_config := NULL;
        END;
        
        -- Use calculate_game_winner to determine set winner from points_a/points_b
        IF v_scoring_config IS NOT NULL AND v_points_a IS NOT NULL THEN
            v_winner := calculate_game_winner(v_points_a, v_points_b, v_scoring_config);
            
            IF v_winner = 'A' THEN
                v_winner_entry_id := NEW.entry_a_id;
            ELSIF v_winner = 'B' THEN
                v_winner_entry_id := NEW.entry_b_id;
            ELSE
                -- Fallback: higher score wins
                IF v_points_a > v_points_b THEN
                    v_winner_entry_id := NEW.entry_a_id;
                ELSIF v_points_b > v_points_a THEN
                    v_winner_entry_id := NEW.entry_b_id;
                ELSE
                    v_winner_entry_id := NEW.entry_a_id;
                END IF;
            END IF;
        ELSE
            -- Fallback: simple score comparison (legacy behavior)
            IF v_points_a > v_points_b THEN
                v_winner_entry_id := NEW.entry_a_id;
            ELSIF v_points_b > v_points_a THEN
                v_winner_entry_id := NEW.entry_b_id;
            ELSE
                v_winner_entry_id := NEW.entry_a_id;
            END IF;
        END IF;
        
        -- Get next match
        v_next_match_id := NEW.next_match_id;
        
        IF v_next_match_id IS NOT NULL AND v_winner_entry_id IS NOT NULL THEN
            -- Get current entries in next match
            SELECT entry_a_id, entry_b_id INTO v_next_entry_a, v_next_entry_b
            FROM matches WHERE id = v_next_match_id
            FOR UPDATE;
            
            -- Place winner in first empty slot
            IF v_next_entry_a IS NULL THEN
                UPDATE matches SET entry_a_id = v_winner_entry_id WHERE id = v_next_match_id;
            ELSIF v_next_entry_b IS NULL THEN
                UPDATE matches SET entry_b_id = v_winner_entry_id WHERE id = v_next_match_id;
            END IF;
            
            -- Check if next match is now ready (both entries present)
            SELECT entry_a_id, entry_b_id INTO v_next_entry_a, v_next_entry_b
            FROM matches WHERE id = v_next_match_id;
            
            IF v_next_entry_a IS NOT NULL AND v_next_entry_b IS NOT NULL THEN
                UPDATE matches SET status = 'SCHEDULED' WHERE id = v_next_match_id;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-attach trigger (will replace existing)
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;
CREATE TRIGGER trg_advance_bracket
AFTER UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION advance_bracket_winner();

COMMENT ON FUNCTION advance_bracket_winner() IS 
'Updated to use calculate_set_winner() with sport-specific scoring rules.
Falls back to simple set counting if scoring_config unavailable.';

COMMIT;
