-- ============================================================
-- Migration: 00000000000028_staff_rpcs
-- Purpose:
--   RPCs for staff management and player-as-referee system
-- ============================================================

BEGIN;

-- =============================================================================
-- RPC 1: assign_staff
-- Assigns a user as staff (direct mode) or creates invitation (invite mode)
-- =============================================================================
CREATE OR REPLACE FUNCTION assign_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT,
    p_invite_mode BOOLEAN DEFAULT FALSE
) RETURNS tournament_staff AS $$
DECLARE
    v_staff tournament_staff;
    v_is_organizer BOOLEAN;
    v_tournament_status tournament_status;
BEGIN
    -- Check if user is an organizer
    SELECT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = p_tournament_id
          AND user_id = auth.uid()
          AND role = 'ORGANIZER'
          AND status = 'ACTIVE'
    ) INTO v_is_organizer;

    IF NOT v_is_organizer THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can assign staff';
    END IF;

    -- Validate role
    IF p_role NOT IN ('EXTERNAL_REFEREE', 'PLAYER_REFEREE') THEN
        RAISE EXCEPTION 'Invalid role. Must be EXTERNAL_REFEREE or PLAYER_REFEREE';
    END IF;

    -- Check tournament status (can't modify staff during LIVE/COMPLETED)
    SELECT status INTO v_tournament_status
    FROM tournaments WHERE id = p_tournament_id;

    IF v_tournament_status IN ('LIVE', 'COMPLETED') THEN
        RAISE EXCEPTION 'Cannot modify staff during LIVE or COMPLETED tournament';
    END IF;

    -- Validate user exists
    IF NOT EXISTS (SELECT 1 FROM persons WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'User does not have a linked person profile';
    END IF;

    -- Insert or update staff record
    INSERT INTO tournament_staff (tournament_id, user_id, role, status, invited_by, invite_mode, expires_at)
    VALUES (
        p_tournament_id, 
        p_user_id, 
        p_role,
        CASE WHEN p_invite_mode THEN 'PENDING' ELSE 'ACTIVE' END,
        auth.uid(), 
        p_invite_mode,
        CASE WHEN p_invite_mode THEN NOW() + INTERVAL '7 days' ELSE NULL END
    )
    ON CONFLICT (tournament_id, user_id) 
    DO UPDATE SET 
        role = EXCLUDED.role,
        status = CASE WHEN EXCLUDED.invite_mode THEN 'PENDING' ELSE 'ACTIVE' END,
        invited_by = EXCLUDED.invited_by,
        invite_mode = EXCLUDED.invite_mode,
        expires_at = EXCLUDED.expires_at
    RETURNING * INTO v_staff;

    RETURN v_staff;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION assign_staff IS 
'Assigns a user as staff. Set invite_mode=true for invitation workflow (PENDING status).';

-- =============================================================================
-- RPC 2: invite_staff (convenience wrapper for invitation mode)
-- =============================================================================
CREATE OR REPLACE FUNCTION invite_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT
) RETURNS tournament_staff AS $$
BEGIN
    RETURN assign_staff(p_tournament_id, p_user_id, p_role, TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION invite_staff IS 
'Convenience wrapper for assign_staff with invite_mode=true.';

-- =============================================================================
-- RPC 3: accept_invitation
-- Accepts a pending invitation
-- =============================================================================
CREATE OR REPLACE FUNCTION accept_invitation(p_tournament_id UUID)
RETURNS tournament_staff AS $$
DECLARE
    v_staff tournament_staff;
BEGIN
    -- Verify invitation exists and belongs to current user
    UPDATE tournament_staff
    SET status = 'ACTIVE'
    WHERE tournament_id = p_tournament_id
      AND user_id = auth.uid()
      AND status = 'PENDING'
      AND expires_at > NOW()
    RETURNING * INTO v_staff;

    IF v_staff IS NULL THEN
        RAISE EXCEPTION 'No valid invitation found or invitation has expired';
    END IF;

    RETURN v_staff;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION accept_invitation IS 
'Accepts a pending staff invitation. Fails if invitation expired or does not exist.';

-- =============================================================================
-- RPC 4: reject_invitation
-- Rejects a pending invitation
-- =============================================================================
CREATE OR REPLACE FUNCTION reject_invitation(p_tournament_id UUID)
RETURNS tournament_staff AS $$
DECLARE
    v_staff tournament_staff;
BEGIN
    UPDATE tournament_staff
    SET status = 'REJECTED'
    WHERE tournament_id = p_tournament_id
      AND user_id = auth.uid()
      AND status = 'PENDING'
    RETURNING * INTO v_staff;

    IF v_staff IS NULL THEN
        RAISE EXCEPTION 'No pending invitation found';
    END IF;

    RETURN v_staff;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION reject_invitation IS 
'Rejects a pending staff invitation.';

-- =============================================================================
-- RPC 5: revoke_staff
-- Revokes a staff member's access
-- =============================================================================
CREATE OR REPLACE FUNCTION revoke_staff(
    p_tournament_id UUID,
    p_target_user_id UUID
) RETURNS VOID AS $$
DECLARE
    v_is_organizer BOOLEAN;
BEGIN
    -- Verify current user is organizer
    SELECT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = p_tournament_id
          AND user_id = auth.uid()
          AND role = 'ORGANIZER'
          AND status = 'ACTIVE'
    ) INTO v_is_organizer;

    IF NOT v_is_organizer THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can revoke staff';
    END IF;

    -- Cannot revoke self
    IF p_target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot revoke your own organizer access';
    END IF;

    -- Update status to REVOKED
    UPDATE tournament_staff
    SET status = 'REVOKED'
    WHERE tournament_id = p_tournament_id
      AND user_id = p_target_user_id
      AND role != 'ORGANIZER'; -- Never revoke organizer role

    -- Also deactivate volunteer status if exists
    UPDATE referee_volunteers
    SET is_active = FALSE
    WHERE tournament_id = p_tournament_id
      AND user_id = p_target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION revoke_staff IS 
'Revokes a staff member access. Organizer cannot revoke themselves.';

-- =============================================================================
-- RPC 6: toggle_referee_volunteer
-- Player toggles their willingness to referee
-- =============================================================================
CREATE OR REPLACE FUNCTION toggle_referee_volunteer(
    p_tournament_id UUID,
    p_is_active BOOLEAN
) RETURNS VOID AS $$
DECLARE
    v_person_id UUID;
    v_user_id UUID;
    v_is_checked_in BOOLEAN;
    v_tournament_status tournament_status;
BEGIN
    -- Get person for current user
    SELECT id, user_id INTO v_person_id, v_user_id
    FROM persons WHERE user_id = auth.uid();

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION 'User does not have a linked person profile';
    END IF;

    -- Get tournament status
    SELECT status INTO v_tournament_status
    FROM tournaments WHERE id = p_tournament_id;

    IF v_tournament_status NOT IN ('CHECK_IN', 'LIVE') THEN
        RAISE EXCEPTION 'Can only volunteer during CHECK_IN or LIVE tournament';
    END IF;

    -- Verify user is checked-in
    SELECT EXISTS (
        SELECT 1 FROM tournament_entries te
        JOIN entry_members em ON em.entry_id = te.id
        WHERE te.tournament_id = p_tournament_id
          AND em.person_id = v_person_id
          AND te.checked_in_at IS NOT NULL
    ) INTO v_is_checked_in;

    IF NOT v_is_checked_in THEN
        RAISE EXCEPTION 'Must be checked-in to volunteer as referee';
    END IF;

    IF p_is_active THEN
        -- Activate volunteer
        INSERT INTO referee_volunteers (tournament_id, person_id, user_id, is_active)
        VALUES (p_tournament_id, v_person_id, v_user_id, TRUE)
        ON CONFLICT (tournament_id, person_id) 
        DO UPDATE SET is_active = TRUE, updated_at = NOW();

        -- Create or update staff record as PLAYER_REFEREE
        INSERT INTO tournament_staff (tournament_id, user_id, role, status)
        VALUES (p_tournament_id, v_user_id, 'PLAYER_REFEREE', 'ACTIVE')
        ON CONFLICT (tournament_id, user_id) 
        DO UPDATE SET 
            role = 'PLAYER_REFEREE', 
            status = 'ACTIVE',
            invite_mode = FALSE; -- Volunteers don't need invite mode
    ELSE
        -- Deactivate volunteer
        UPDATE referee_volunteers 
        SET is_active = FALSE, updated_at = NOW()
        WHERE tournament_id = p_tournament_id AND person_id = v_person_id;

        -- Revoke PLAYER_REFEREE status
        UPDATE tournament_staff
        SET status = 'REVOKED'
        WHERE tournament_id = p_tournament_id 
          AND user_id = v_user_id 
          AND role = 'PLAYER_REFEREE';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION toggle_referee_volunteer IS 
'Toggles player referee volunteer status. Requires check-in.';

-- =============================================================================
-- RPC 7: generate_referee_suggestions
-- Auto-suggests referees for all matches without confirmed referee
-- =============================================================================
CREATE OR REPLACE FUNCTION generate_referee_suggestions(p_category_id UUID)
RETURNS TABLE(match_id UUID, user_id UUID) AS $$
DECLARE
    v_match RECORD;
    v_available_refs UUID[];
    v_ref_idx INTEGER := 0;
BEGIN
    -- Get all matches in this category without confirmed referee
    FOR v_match IN 
        SELECT m.id, m.round_name, c.tournament_id
        FROM matches m
        JOIN categories c ON c.id = m.category_id
        WHERE m.category_id = p_category_id
          AND m.status IN ('SCHEDULED', 'CALLING')
          AND NOT EXISTS (
              SELECT 1 FROM referee_assignments ra
              WHERE ra.match_id = m.id AND ra.is_confirmed = TRUE
          )
        ORDER BY 
            CASE m.round_name 
                WHEN 'Final' THEN 1 
                WHEN 'Semi-Final' THEN 2 
                WHEN 'Quarter-Final' THEN 3 
                ELSE 4 
            END,
            m.id
    LOOP
        -- Get available referees for this match (round-robin by matches_refereed)
        SELECT ARRAY(
            SELECT ar.user_id
            FROM available_referees(ar.match_id) ar
            CROSS JOIN LATERAL (
                SELECT ar.user_id, 
                       COALESCE(
                           (SELECT COUNT(*) 
                            FROM referee_assignments ra2 
                            WHERE ra2.user_id = ar.user_id AND ra2.is_confirmed = TRUE),
                           0
                       ) AS ref_count
            ) counts
            WHERE ar.match_id = v_match.id
            ORDER BY counts.ref_count ASC
            LIMIT 5
        ) INTO v_available_refs;

        -- Assign next referee in round-robin
        IF array_length(v_available_refs, 1) > 0 THEN
            v_ref_idx := (v_ref_idx % array_length(v_available_refs, 1)) + 1;
            
            -- Insert or update suggestion
            INSERT INTO referee_assignments (match_id, user_id, assigned_by, is_suggested)
            VALUES (v_match.id, v_available_refs[v_ref_idx], auth.uid(), TRUE)
            ON CONFLICT (match_id) 
            DO UPDATE SET 
                user_id = v_available_refs[v_ref_idx],
                is_suggested = TRUE,
                is_confirmed = FALSE,
                assigned_by = EXCLUDED.assigned_by;

            match_id := v_match.id;
            user_id := v_available_refs[v_ref_idx];
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION generate_referee_suggestions IS 
'Generates auto-suggestions for referee assignments using round-robin balancing.';

-- =============================================================================
-- RPC 8: confirm_referee_assignment
-- Confirms a suggested assignment or manually assigns a referee
-- =============================================================================
CREATE OR REPLACE FUNCTION confirm_referee_assignment(
    p_match_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_is_organizer_override BOOLEAN DEFAULT FALSE
) RETURNS referee_assignments AS $$
DECLARE
    v_assignment referee_assignments;
    v_match matches%ROWTYPE;
    v_is_authorized BOOLEAN;
BEGIN
    -- Get match info
    SELECT * INTO v_match FROM matches WHERE id = p_match_id;

    IF v_match IS NULL THEN
        RAISE EXCEPTION 'Match not found';
    END IF;

    -- Check authorization
    IF p_is_organizer_override THEN
        -- Organizer override
        SELECT EXISTS (
            SELECT 1 FROM tournament_staff ts
            JOIN categories c ON c.tournament_id = ts.tournament_id
            WHERE c.id = v_match.category_id
              AND ts.user_id = auth.uid()
              AND ts.role = 'ORGANIZER'
              AND ts.status = 'ACTIVE'
        ) INTO v_is_authorized;
    ELSE
        -- User must be the suggested referee or organizer
        SELECT EXISTS (
            SELECT 1 FROM referee_assignments ra
            WHERE ra.match_id = p_match_id 
              AND ra.user_id = auth.uid()
              AND ra.is_suggested = TRUE
        ) INTO v_is_authorized;

        IF NOT v_is_authorized THEN
            SELECT EXISTS (
                SELECT 1 FROM tournament_staff ts
                JOIN categories c ON c.tournament_id = ts.tournament_id
                WHERE c.id = v_match.category_id
                  AND ts.user_id = auth.uid()
                  AND ts.role = 'ORGANIZER'
                  AND ts.status = 'ACTIVE'
            ) INTO v_is_authorized;
        END IF;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Access denied: Not authorized for this match';
    END IF;

    -- Use provided user_id or get from suggestion
    IF p_user_id IS NULL THEN
        SELECT user_id INTO p_user_id
        FROM referee_assignments
        WHERE match_id = p_match_id;
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'No referee specified and no suggestion found';
    END IF;

    -- Verify referee is available (not playing this match)
    IF EXISTS (
        SELECT 1 FROM matches m2
        JOIN categories c2 ON c2.id = m2.category_id
        JOIN tournament_entries te2 ON te2.category_id = c2.id
        JOIN entry_members em2 ON em2.entry_id = te2.id
        JOIN persons p ON p.id = em2.person_id
        WHERE m2.id = p_match_id AND p.user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'Cannot assign a player who is in this match as referee';
    END IF;

    -- Confirm or create assignment
    INSERT INTO referee_assignments (match_id, user_id, assigned_by, is_suggested, is_confirmed)
    VALUES (p_match_id, p_user_id, auth.uid(), FALSE, TRUE)
    ON CONFLICT (match_id) 
    DO UPDATE SET 
        user_id = EXCLUDED.user_id,
        is_suggested = FALSE,
        is_confirmed = TRUE,
        assigned_by = EXCLUDED.assigned_by
    RETURNING * INTO v_assignment;

    -- Also update matches.referee_id
    UPDATE matches SET referee_id = p_user_id WHERE id = p_match_id;

    RETURN v_assignment;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION confirm_referee_assignment IS 
'Confirms a suggested assignment or manually assigns a referee. Updates matches.referee_id.';

-- =============================================================================
-- RPC 9: clear_match_referee
-- Removes referee from a match (organizer only)
-- =============================================================================
CREATE OR REPLACE FUNCTION clear_match_referee(p_match_id UUID)
RETURNS VOID AS $$
DECLARE
    v_match matches%ROWTYPE;
BEGIN
    SELECT * INTO v_match FROM matches WHERE id = p_match_id;

    IF v_match IS NULL THEN
        RAISE EXCEPTION 'Match not found';
    END IF;

    -- Verify organizer
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = v_match.category_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can clear referee';
    END IF;

    -- Clear referee
    UPDATE matches SET referee_id = NULL WHERE id = p_match_id;

    -- Clear assignment confirmation
    UPDATE referee_assignments 
    SET is_confirmed = FALSE 
    WHERE match_id = p_match_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION clear_match_referee IS 
'Clears referee assignment from a match. Organizer only.';

COMMIT;
