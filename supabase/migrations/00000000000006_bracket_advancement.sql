-- Migration: 00000000000006_bracket_advancement
-- Purpose: Auto-advance bracket winners when match is marked FINISHED

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
    v_sets_json JSONB;
BEGIN
    -- Only trigger when match becomes FINISHED
    IF NEW.status = 'FINISHED' AND OLD.status != 'FINISHED' THEN
        
        -- Get sets_json from scores table for this match
        SELECT sets_json INTO v_sets_json
        FROM scores WHERE match_id = NEW.id;
        
        -- Determine winner by sets won
        -- Count sets won by entry_a
        v_entry_a_sets := COALESCE(
            (SELECT COUNT(*) 
             FROM jsonb_array_elements(v_sets_json) AS s
             WHERE (s->>'a')::INTEGER > (s->>'b')::INTEGER),
            0
        );
        
        -- Count sets won by entry_b
        v_entry_b_sets := COALESCE(
            (SELECT COUNT(*) 
             FROM jsonb_array_elements(v_sets_json) AS s
             WHERE (s->>'b')::INTEGER > (s->>'a')::INTEGER),
            0
        );
        
        -- Determine winner entry
        IF v_entry_a_sets > v_entry_b_sets THEN
            v_winner_entry_id := NEW.entry_a_id;
        ELSIF v_entry_b_sets > v_entry_a_sets THEN
            v_winner_entry_id := NEW.entry_b_id;
        ELSE
            -- Tie-breaker: use entry_a if tied (deterministic)
            v_winner_entry_id := NEW.entry_a_id;
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

-- Attach trigger
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;
CREATE TRIGGER trg_advance_bracket
AFTER UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION advance_bracket_winner();
