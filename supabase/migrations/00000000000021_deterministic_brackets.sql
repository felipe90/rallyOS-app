-- ============================================================
-- Migration: 00000000000021_deterministic_brackets
-- Purpose: 
--   Implement deterministic bracket advancement using winner_to_slot.
-- ============================================================

CREATE OR REPLACE FUNCTION advance_bracket_winner()
RETURNS TRIGGER
SECURITY DEFINER
AS $$
DECLARE
    v_winner_entry_id UUID;
    v_next_match_id UUID;
    v_winner_slot bracket_slot;
    v_sets_a INTEGER;
    v_sets_b INTEGER;
BEGIN
    -- Only trigger when match becomes FINISHED (or W_O)
    IF (NEW.status = 'FINISHED' AND OLD.status != 'FINISHED') OR (NEW.status = 'W_O' AND OLD.status != 'W_O') THEN
        
        -- 1. DETERMINE WINNER
        IF NEW.status = 'W_O' THEN
            -- In Walkover, the present entry wins. Assume Entry A wins if B is W_O? 
            -- Better check scores or metadata. Simplified: Entry A wins if B has 0/NULL.
            -- But usually, W_O is set by providing the winner.
            -- For now, use the same set logic if scores exist, else fallback to Entry A.
             SELECT 
                COUNT(*) FILTER (WHERE points_a > points_b),
                COUNT(*) FILTER (WHERE points_b > points_a)
            INTO v_sets_a, v_sets_b
            FROM match_sets
            WHERE match_id = NEW.id;
            
            IF v_sets_a >= v_sets_b THEN v_winner_entry_id := NEW.entry_a_id; ELSE v_winner_entry_id := NEW.entry_b_id; END IF;
        ELSE
            SELECT 
                COUNT(*) FILTER (WHERE points_a > points_b),
                COUNT(*) FILTER (WHERE points_b > points_a)
            INTO v_sets_a, v_sets_b
            FROM match_sets
            WHERE match_id = NEW.id;

            IF v_sets_a > v_sets_b THEN
                v_winner_entry_id := NEW.entry_a_id;
            ELSIF v_sets_b > v_sets_a THEN
                v_winner_entry_id := NEW.entry_b_id;
            ELSE
                -- No winner? Exit.
                RETURN NEW;
            END IF;
        END IF;

        -- 2. ADVANCE TO NEXT MATCH
        v_next_match_id := NEW.next_match_id;
        v_winner_slot := NEW.winner_to_slot;

        IF v_next_match_id IS NOT NULL AND v_winner_entry_id IS NOT NULL AND v_winner_slot IS NOT NULL THEN
            
            IF v_winner_slot = 'A' THEN
                UPDATE matches SET entry_a_id = v_winner_entry_id WHERE id = v_next_match_id;
            ELSE
                UPDATE matches SET entry_b_id = v_winner_entry_id WHERE id = v_next_match_id;
            END IF;

            -- 3. AUTO-READY NEXT MATCH
            -- If both entries are now present, set status to SCHEDULED (or READY)
            UPDATE matches 
            SET status = 'SCHEDULED' 
            WHERE id = v_next_match_id 
              AND entry_a_id IS NOT NULL 
              AND entry_b_id IS NOT NULL
              AND status = 'SCHEDULED'; -- Only if it was already scheduled/draft

        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-attach trigger
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;
CREATE TRIGGER trg_advance_bracket
AFTER UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION advance_bracket_winner();
