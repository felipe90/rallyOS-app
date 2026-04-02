-- ============================================================
-- Migration: 00000000000037_add_third_place_rpcs
-- Purpose: RPCs for third place match workflow
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Function: offer_third_place
-- Organizer offers third place to players after semi-final ends
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION offer_third_place(p_match_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_category_id UUID;
    v_round_name TEXT;
    v_status TEXT;
BEGIN
    -- Get match info
    SELECT category_id, round_name, status INTO v_category_id, v_round_name, v_status
    FROM matches WHERE id = p_match_id;

    -- Validate match exists
    IF v_category_id IS NULL THEN
        RAISE EXCEPTION 'Match not found: %', p_match_id;
    END IF;

    -- Validate match is finished
    IF v_status != 'FINISHED' THEN
        RAISE EXCEPTION 'Match must be FINISHED to offer third place. Current status: %', v_status;
    END IF;

    -- Validate it's a semi-final (or earlier round that could have third place)
    IF v_round_name NOT LIKE '%Semi-Final%' AND v_round_name NOT LIKE '%Quarter%' THEN
        RAISE EXCEPTION 'Third place only available for Semi-Final or Quarter-Final matches. Current: %', v_round_name;
    END IF;

    -- Check organizer permission
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = v_category_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    ) THEN
        RAISE EXCEPTION 'Only the organizer can offer third place';
    END IF;

    -- Update the match
    UPDATE matches 
    SET third_place_pending = TRUE 
    WHERE id = p_match_id;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION offer_third_place(UUID) TO authenticated;

COMMENT ON FUNCTION offer_third_place(UUID) IS 
'Organizer offers third place to players after a semi-final match ends.
Returns TRUE if successful. Raises exception if invalid state or permission denied.';

-- ═══════════════════════════════════════════════════════════════
-- Function: accept_third_place
-- Player accepts or rejects playing third place
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION accept_third_place(p_match_id UUID, p_accepted BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_entry_a UUID;
    v_entry_b UUID;
    v_user_entry_id UUID;
BEGIN
    -- Check if third place was offered
    IF NOT EXISTS (
        SELECT 1 FROM matches 
        WHERE id = p_match_id 
        AND third_place_pending = TRUE
    ) THEN
        RAISE EXCEPTION 'Third place was not offered for this match';
    END IF;

    -- Get entries in the match
    SELECT entry_a_id, entry_b_id INTO v_entry_a, v_entry_b
    FROM matches WHERE id = p_match_id;

    -- Check if user is one of the players
    SELECT em.entry_id INTO v_user_entry_id
    FROM entry_members em
    JOIN persons p ON em.person_id = p.id
    WHERE p.user_id = auth.uid()
    AND em.entry_id IN (v_entry_a, v_entry_b);

    IF v_user_entry_id IS NULL THEN
        RAISE EXCEPTION 'You are not a player in this match';
    END IF;

    -- Update acceptance
    UPDATE matches
    SET third_place_accepted = p_accepted
    WHERE id = p_match_id;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION accept_third_place(UUID, BOOLEAN) TO authenticated;

COMMENT ON FUNCTION accept_third_place(UUID, BOOLEAN) IS 
'Player accepts (TRUE) or rejects (FALSE) playing third place.
Returns TRUE if successful. Only players in the match can call.';

-- ═══════════════════════════════════════════════════════════════
-- Function: get_match_loser
-- Returns the entry_id of the loser from a finished match
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_match_loser(p_match_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_entry_a UUID;
    v_entry_b UUID;
    v_points_a INTEGER;
    v_points_b INTEGER;
    v_winner_entry_id UUID;
BEGIN
    -- Get entries and current score
    SELECT entry_a_id, entry_b_id, 
           COALESCE(s.points_a, 0), COALESCE(s.points_b, 0)
    INTO v_entry_a, v_entry_b, v_points_a, v_points_b
    FROM matches m
    LEFT JOIN scores s ON m.id = s.match_id
    WHERE m.id = p_match_id;

    IF v_entry_a IS NULL OR v_entry_b IS NULL THEN
        RETURN NULL;
    END IF;

    -- Determine winner by points (for single-set, this is the set winner)
    IF v_points_a > v_points_b THEN
        v_winner_entry_id := v_entry_a;
    ELSIF v_points_b > v_points_a THEN
        v_winner_entry_id := v_entry_b;
    ELSE
        -- Tie - no clear winner, return NULL
        RETURN NULL;
    END IF;

    -- Return the loser
    IF v_winner_entry_id = v_entry_a THEN
        RETURN v_entry_b;
    ELSE
        RETURN v_entry_a;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_match_loser(UUID) TO authenticated;

COMMENT ON FUNCTION get_match_loser(UUID) IS 
'Returns the entry_id of the loser from a match based on scores.
Returns NULL if match not finished or scores are tied.';

-- ═══════════════════════════════════════════════════════════════
-- Function: create_third_place_match
-- Creates third place match from two semi-final losers
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_third_place_match(p_semi_a UUID, p_semi_b UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_semi_a RECORD;
    v_semi_b RECORD;
    v_loser_a UUID;
    v_loser_b UUID;
    v_category_id UUID;
    v_new_match_id UUID;
BEGIN
    -- Get semi A info
    SELECT category_id, round_name, status, third_place_accepted
    INTO v_semi_a
    FROM matches WHERE id = p_semi_a;

    -- Get semi B info
    SELECT category_id, round_name, status, third_place_accepted
    INTO v_semi_b
    FROM matches WHERE id = p_semi_b;

    -- Validate both are finished
    IF v_semi_a.status != 'FINISHED' OR v_semi_b.status != 'FINISHED' THEN
        RAISE EXCEPTION 'Both semi-finals must be FINISHED';
    END IF;

    -- Validate same category
    IF v_semi_a.category_id != v_semi_b.category_id THEN
        RAISE EXCEPTION 'Both semi-finals must be in the same category';
    END IF;

    -- Validate both accepted
    IF v_semi_a.third_place_accepted != TRUE OR v_semi_b.third_place_accepted != TRUE THEN
        RAISE EXCEPTION 'Both players must accept third place. Got: semi_a=%, semi_b=%', 
            v_semi_a.third_place_accepted, v_semi_b.third_place_accepted;
    END IF;

    -- Check organizer permission
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = v_semi_a.category_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    ) THEN
        RAISE EXCEPTION 'Only the organizer can create third place match';
    END IF;

    -- Get losers
    v_loser_a := get_match_loser(p_semi_a);
    v_loser_b := get_match_loser(p_semi_b);

    IF v_loser_a IS NULL OR v_loser_b IS NULL THEN
        RAISE EXCEPTION 'Could not determine losers from semi-finals';
    END IF;

    v_category_id := v_semi_a.category_id;

    -- Create third place match
    INSERT INTO matches (category_id, round_name, status, entry_a_id, entry_b_id)
    VALUES (v_category_id, 'Third Place', 'SCHEDULED', v_loser_a, v_loser_b)
    RETURNING id INTO v_new_match_id;

    RETURN v_new_match_id;
END;
$$;

GRANT EXECUTE ON FUNCTION create_third_place_match(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION create_third_place_match(UUID, UUID) IS 
'Creates a third place match between losers of two semi-finals.
Returns the new match ID. Only organizer can call.
Both players must have accepted third place.';

COMMIT;
