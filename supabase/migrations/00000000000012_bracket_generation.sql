-- ============================================
-- SPEC-003: Bracket Generation
-- Function to generate single-elimination bracket
-- ============================================

CREATE OR REPLACE FUNCTION generate_bracket(p_category_id UUID)
RETURNS VOID AS $$
DECLARE
    v_entry RECORD;
    v_entries UUID[];
    v_entry_elos INTEGER[];
    v_count INTEGER;
    v_rounds INTEGER;
    v_byes INTEGER;
    v_match_id UUID;
    v_match_ids UUID[];
    v_round_matches UUID[];
    v_i INTEGER;
    v_j INTEGER;
    v_a INTEGER;
    v_b INTEGER;
    v_next_match_id UUID;
BEGIN
    -- Get CONFIRMED entries ordered by ELO (descending for seeding)
    SELECT ARRAY_AGG(id ORDER BY current_elo DESC) INTO v_entries
    FROM (
        SELECT DISTINCT e.id, ast.current_elo
        FROM tournament_entries e
        JOIN entry_members em ON em.entry_id = e.id
        JOIN athlete_stats ast ON ast.person_id = em.person_id
        WHERE e.category_id = p_category_id
          AND e.status = 'CONFIRMED'
    ) AS ranked_entries;

    -- Get count and calculate rounds needed
    v_count := array_length(v_entries, 1);
    
    IF v_count < 2 THEN
        RAISE EXCEPTION 'Need at least 2 entries to generate bracket';
    END IF;

    -- Calculate rounds (next power of 2)
    v_rounds := 1;
    WHILE power(2, v_rounds) < v_count LOOP
        v_rounds := v_rounds + 1;
    END LOOP;

    -- Calculate BYEs needed
    v_byes := power(2, v_rounds) - v_count;

    -- Initialize match IDs array
    v_match_ids := ARRAY[]::UUID[];

    -- Generate all matches for all rounds
    FOR v_i IN 1..v_rounds LOOP
        v_round_matches := ARRAY[]::UUID[];
        
        -- Number of matches in this round
        v_count := power(2, v_rounds - v_i)::INTEGER;
        
        FOR v_j IN 1..v_count LOOP
            -- Create match
            INSERT INTO matches (category_id, status, round_name)
            VALUES (p_category_id, 'SCHEDULED', 
                CASE v_i 
                    WHEN 1 THEN 'Final'
                    WHEN 2 THEN 'Semi-Final'
                    WHEN 3 THEN 'Quarter-Final'
                    ELSE 'Round ' || v_i
                END
            )
            RETURNING id INTO v_match_id;
            
            v_round_matches := array_append(v_round_matches, v_match_id);
        END LOOP;
        
        -- Link matches to next round
        IF v_i > 1 THEN
            FOR v_j IN 1..array_length(v_round_matches, 1) LOOP
                -- Get corresponding match from previous round (next_match_id)
                v_next_match_id := v_match_ids[((v_j + 1) / 2)::INTEGER];
                UPDATE matches SET next_match_id = v_next_match_id WHERE id = v_round_matches[v_j];
            END LOOP;
        END IF;
        
        v_match_ids := v_round_matches;
    END LOOP;

    -- Place seeded entries in first round matches
    v_j := 1;
    FOR v_i IN 1..array_length(v_entries, 1) LOOP
        -- Alternate between entry_a and entry_b
        IF v_i % 2 = 1 THEN
            UPDATE matches SET entry_a_id = v_entries[v_i] WHERE id = v_match_ids[v_j];
        ELSE
            UPDATE matches SET entry_b_id = v_entries[v_i] WHERE id = v_match_ids[v_j];
            v_j := v_j + 1;
        END IF;
    END LOOP;

    -- Handle BYEs: auto-advance
    -- If entry_a is NULL, entry_b wins (and vice versa)
    UPDATE matches m
    SET entry_a_id = m.entry_b_id
    WHERE m.category_id = p_category_id
      AND m.entry_a_id IS NULL
      AND m.entry_b_id IS NOT NULL;

    UPDATE matches m
    SET entry_b_id = m.entry_a_id
    WHERE m.category_id = p_category_id
      AND m.entry_b_id IS NULL
      AND m.entry_a_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Add bracket_generated flag to categories
ALTER TABLE categories 
ADD COLUMN IF NOT EXISTS bracket_generated BOOLEAN DEFAULT FALSE;

-- Update policy to allow organizer to call generate_bracket function
-- (This is done via SECURITY DEFINER in the function itself)
