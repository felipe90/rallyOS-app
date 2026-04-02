


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."assignment_type" AS ENUM (
    'AUTOMATIC',
    'MANUAL',
    'LOSER_ASSIGNED'
);


ALTER TYPE "public"."assignment_type" OWNER TO "postgres";


CREATE TYPE "public"."athlete_rank" AS ENUM (
    'BRONZE',
    'SILVER',
    'GOLD',
    'PLATINUM',
    'DIAMOND'
);


ALTER TYPE "public"."athlete_rank" OWNER TO "postgres";


CREATE TYPE "public"."bracket_slot" AS ENUM (
    'A',
    'B'
);


ALTER TYPE "public"."bracket_slot" OWNER TO "postgres";


CREATE TYPE "public"."bracket_status" AS ENUM (
    'PENDING',
    'IN_PROGRESS',
    'COMPLETED'
);


ALTER TYPE "public"."bracket_status" OWNER TO "postgres";


CREATE TYPE "public"."elo_change_type" AS ENUM (
    'MATCH_WIN',
    'MATCH_LOSS',
    'ADJUSTMENT'
);


ALTER TYPE "public"."elo_change_type" OWNER TO "postgres";


CREATE TYPE "public"."entry_status" AS ENUM (
    'PENDING_PAYMENT',
    'CONFIRMED',
    'CANCELLED'
);


ALTER TYPE "public"."entry_status" OWNER TO "postgres";


CREATE TYPE "public"."game_mode" AS ENUM (
    'SINGLES',
    'DOUBLES',
    'TEAMS'
);


ALTER TYPE "public"."game_mode" OWNER TO "postgres";


CREATE TYPE "public"."group_status" AS ENUM (
    'PENDING',
    'IN_PROGRESS',
    'COMPLETED'
);


ALTER TYPE "public"."group_status" OWNER TO "postgres";


CREATE TYPE "public"."match_phase" AS ENUM (
    'ROUND_ROBIN',
    'KNOCKOUT',
    'BRONZE',
    'FINAL'
);


ALTER TYPE "public"."match_phase" OWNER TO "postgres";


CREATE TYPE "public"."match_status" AS ENUM (
    'SCHEDULED',
    'CALLING',
    'READY',
    'LIVE',
    'FINISHED',
    'W_O',
    'SUSPENDED'
);


ALTER TYPE "public"."match_status" OWNER TO "postgres";


CREATE TYPE "public"."member_status" AS ENUM (
    'ACTIVE',
    'WALKED_OVER',
    'DISQUALIFIED'
);


ALTER TYPE "public"."member_status" OWNER TO "postgres";


CREATE TYPE "public"."sport_scoring_system" AS ENUM (
    'POINTS',
    'GAMES'
);


ALTER TYPE "public"."sport_scoring_system" OWNER TO "postgres";


CREATE TYPE "public"."staff_status" AS ENUM (
    'PENDING',
    'ACTIVE',
    'REJECTED',
    'REVOKED'
);


ALTER TYPE "public"."staff_status" OWNER TO "postgres";


CREATE TYPE "public"."tournament_status" AS ENUM (
    'DRAFT',
    'REGISTRATION',
    'CHECK_IN',
    'LIVE',
    'COMPLETED',
    'PRE_TOURNAMENT'
);


ALTER TYPE "public"."tournament_status" OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."tournament_staff" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid",
    "user_id" "uuid",
    "role" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "status" "public"."staff_status" DEFAULT 'ACTIVE'::"public"."staff_status",
    "invite_mode" boolean DEFAULT false,
    "invited_by" "uuid",
    "expires_at" timestamp with time zone,
    CONSTRAINT "tournament_staff_role_check" CHECK (("role" = ANY (ARRAY['ORGANIZER'::"text", 'EXTERNAL_REFEREE'::"text"])))
);


ALTER TABLE "public"."tournament_staff" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."accept_invitation"("p_tournament_id" "uuid") RETURNS "public"."tournament_staff"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."accept_invitation"("p_tournament_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."accept_invitation"("p_tournament_id" "uuid") IS 'Accepts a pending staff invitation. Fails if invitation expired or does not exist.';



CREATE OR REPLACE FUNCTION "public"."accept_third_place"("p_match_id" "uuid", "p_accepted" boolean) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."accept_third_place"("p_match_id" "uuid", "p_accepted" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."accept_third_place"("p_match_id" "uuid", "p_accepted" boolean) IS 'Player accepts (TRUE) or rejects (FALSE) playing third place.
Returns TRUE if successful. Only players in the match can call.';



CREATE OR REPLACE FUNCTION "public"."add_member_to_group"("p_group_id" "uuid", "p_entry_id" "uuid", "p_seed" integer DEFAULT NULL::integer) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_member_id UUID;
    v_current_count INTEGER;
    v_max_seed INTEGER;
    v_person_id UUID;
BEGIN
    -- Check group exists and is editable
    IF NOT EXISTS (
        SELECT 1 FROM round_robin_groups 
        WHERE id = p_group_id 
        AND status = 'PENDING'
    ) THEN
        RAISE EXCEPTION 'Can only add members to PENDING groups';
    END IF;
    
    -- Check current member count
    SELECT COUNT(*) INTO v_current_count
    FROM group_members
    WHERE group_id = p_group_id;
    
    IF v_current_count >= 5 THEN
        RAISE EXCEPTION 'Group already has maximum 5 members';
    END IF;
    
    -- Get person_id from entry
    SELECT person_id INTO v_person_id
    FROM tournament_entries
    WHERE id = p_entry_id;
    
    -- Check person not already in another group of same tournament
    IF EXISTS (
        SELECT 1 FROM group_members gm
        JOIN round_robin_groups rrg ON gm.group_id = rrg.id
        WHERE gm.person_id = v_person_id
        AND rrg.tournament_id = (SELECT tournament_id FROM round_robin_groups WHERE id = p_group_id)
    ) THEN
        RAISE EXCEPTION 'Person is already in another group for this tournament';
    END IF;
    
    -- If no seed provided, assign next available
    IF p_seed IS NULL THEN
        SELECT COALESCE(MAX(seed), 0) + 1 INTO v_max_seed
        FROM group_members
        WHERE group_id = p_group_id;
        p_seed := v_max_seed;
    END IF;
    
    -- Check seed not already taken
    IF EXISTS (
        SELECT 1 FROM group_members 
        WHERE group_id = p_group_id AND seed = p_seed
    ) THEN
        RAISE EXCEPTION 'Seed % already taken in this group', p_seed;
    END IF;
    
    INSERT INTO group_members (group_id, entry_id, person_id, seed)
    VALUES (p_group_id, p_entry_id, v_person_id, p_seed)
    RETURNING id INTO v_member_id;
    
    RETURN v_member_id;
END;
$$;


ALTER FUNCTION "public"."add_member_to_group"("p_group_id" "uuid", "p_entry_id" "uuid", "p_seed" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."advance_bracket_winner"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
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
$$;


ALTER FUNCTION "public"."advance_bracket_winner"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."advance_bracket_winner"() IS 'Updated to use calculate_set_winner() with sport-specific scoring rules.
Falls back to simple set counting if scoring_config unavailable.';



CREATE OR REPLACE FUNCTION "public"."assign_loser_as_referee"("p_match_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_winner_entry_id UUID;
    v_loser_entry_id UUID;
    v_loser_person_id UUID;
    v_loser_user_id UUID;
    v_next_match_id UUID;
    v_next_group_id UUID;
    v_current_group_id UUID;
BEGIN
    -- Get match info
    SELECT 
        entry_a_id,
        entry_b_id,
        next_match_id,
        group_id
    INTO v_winner_entry_id, v_loser_entry_id, v_next_match_id, v_current_group_id
    FROM matches
    WHERE id = p_match_id;
    
    IF v_next_match_id IS NULL THEN
        RETURN FALSE;  -- No next match (e.g., final)
    END IF;
    
    -- Get next match's group
    SELECT group_id INTO v_next_group_id FROM matches WHERE id = v_next_match_id;
    
    -- Determine winner/loser from score
    IF EXISTS (SELECT 1 FROM scores WHERE match_id = p_match_id) THEN
        SELECT 
            CASE 
                WHEN points_a > points_b THEN entry_a_id
                ELSE entry_b_id
            END,
            CASE 
                WHEN points_a > points_b THEN entry_b_id
                ELSE entry_a_id
            END
        INTO v_winner_entry_id, v_loser_entry_id
        FROM matches
        WHERE id = p_match_id;
    END IF;
    
    -- Get loser user_id
    SELECT p.user_id INTO v_loser_user_id
    FROM tournament_entries te
    JOIN persons p ON te.person_id = p.id
    WHERE te.id = v_loser_entry_id;
    
    IF v_loser_user_id IS NULL THEN
        RETURN FALSE;  -- Shadow profile, cannot be referee
    END IF;
    
    -- BR-LOSER-002: Cross-group check
    IF v_next_group_id != v_current_group_id THEN
        -- Cannot assign cross-group, clear stored loser and return FALSE
        UPDATE matches SET loser_assigned_referee = NULL WHERE id = v_next_match_id;
        RETURN FALSE;
    END IF;
    
    -- Create/update referee assignment
    INSERT INTO referee_assignments (
        match_id,
        user_id,
        assignment_type,
        is_suggested,
        is_confirmed
    )
    VALUES (
        v_next_match_id,
        v_loser_user_id,
        'LOSER_ASSIGNED',
        TRUE,
        FALSE
    )
    ON CONFLICT (match_id) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        assignment_type = 'LOSER_ASSIGNED',
        is_suggested = TRUE,
        is_confirmed = FALSE;
    
    -- Clear the stored loser reference
    UPDATE matches SET loser_assigned_referee = NULL WHERE id = v_next_match_id;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."assign_loser_as_referee"("p_match_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_invite_mode" boolean DEFAULT false) RETURNS "public"."tournament_staff"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."assign_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_invite_mode" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."assign_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_invite_mode" boolean) IS 'Assigns a user as staff. Set invite_mode=true for invitation workflow (PENDING status).';



CREATE OR REPLACE FUNCTION "public"."assign_tournament_creator_as_organizer"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO tournament_staff (tournament_id, user_id, role)
    VALUES (NEW.id, auth.uid(), 'ORGANIZER');
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."assign_tournament_creator_as_organizer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_confirm_free_entry"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_fee_amount INTEGER;
BEGIN
    -- Get fee_amount from the tournament
    SELECT t.fee_amount INTO v_fee_amount
    FROM tournaments t
    JOIN categories c ON c.tournament_id = t.id
    WHERE c.id = NEW.category_id;

    -- If fee is 0 or NULL, auto-confirm the entry
    IF v_fee_amount IS NULL OR v_fee_amount = 0 THEN
        NEW.status := 'CONFIRMED';
    ELSE
        NEW.status := 'PENDING_PAYMENT';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_confirm_free_entry"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_game_winner"("p_score_a" integer, "p_score_b" integer, "p_scoring_config" "jsonb") RETURNS character
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    v_points_to_win INTEGER;
    v_win_by_two BOOLEAN;
    v_scoring_type TEXT;
    v_has_golden_point BOOLEAN;
    v_tiebreak_at INTEGER;
    v_has_tiebreak BOOLEAN;
BEGIN
    -- Handle NULL scores (game not started or in progress)
    IF p_score_a IS NULL OR p_score_b IS NULL THEN
        RETURN NULL;
    END IF;

    -- Extract config values with defaults
    -- Handle both naming conventions: points_to_win_game vs points_per_set
    v_points_to_win := COALESCE(
        (p_scoring_config->>'points_to_win_game')::INTEGER,
        (p_scoring_config->>'points_per_set')::INTEGER,
        4
    );
    v_win_by_two := COALESCE(
        (p_scoring_config->>'win_by_two_points')::BOOLEAN,
        (p_scoring_config->>'win_by_2')::BOOLEAN,
        TRUE
    );
    v_scoring_type := COALESCE(
        (p_scoring_config->>'scoring_type')::TEXT,
        (p_scoring_config->>'type')::TEXT,
        'standard'
    );
    v_has_golden_point := COALESCE(
        (p_scoring_config->>'has_golden_point')::BOOLEAN,
        (p_scoring_config->'golden_point'->>'enabled')::BOOLEAN,
        FALSE
    );
    v_tiebreak_at := COALESCE(
        (p_scoring_config->>'tiebreak_at')::INTEGER,
        (p_scoring_config->'tie_break'->>'at')::INTEGER,
        6
    );
    v_has_tiebreak := COALESCE(
        (p_scoring_config->>'has_tiebreak')::BOOLEAN,
        (p_scoring_config->'tie_break'->>'enabled')::BOOLEAN,
        FALSE
    );

    -- ═══════════════════════════════════════════════════════════════
    -- Handle Tennis 15-30-40 scoring (also used for Padel)
    -- ═══════════════════════════════════════════════════════════════
    IF v_scoring_type = 'tennis_15_30_40' THEN
        -- Standard points are 0, 15, 30, 40 (stored as 0, 1, 2, 3)
        -- v_points_to_win = 4 means first to 4 points (0,1,2,3, then 4+ wins)
        
        -- Check for deuce (40-40 = 3-3)
        IF p_score_a = 3 AND p_score_b = 3 THEN
            -- Deuce state - game not complete yet
            RETURN NULL;
        END IF;

        -- Golden point: at 40-40 (3-3), next point wins (for Padel)
        IF v_has_golden_point AND (p_score_a = 3 OR p_score_b = 3) THEN
            -- Any score beyond 3 means golden point was won
            IF p_score_a > 3 AND p_score_a > p_score_b THEN
                RETURN 'A';
            ELSIF p_score_b > 3 AND p_score_b > p_score_a THEN
                RETURN 'B';
            ELSE
                -- Still at deuce or advantage not yet resolved
                RETURN NULL;
            END IF;
        END IF;

        -- Regular advantage scoring (tennis)
        IF p_score_a >= 3 AND p_score_b >= 3 THEN
            -- Advantage state: need 2-point lead
            IF p_score_a - p_score_b >= 2 THEN
                RETURN 'A';
            ELSIF p_score_b - p_score_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL; -- Not yet decided
            END IF;
        END IF;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Handle Standard/Rally scoring (Pickleball, Table Tennis)
    -- ═══════════════════════════════════════════════════════════════
    IF v_scoring_type = 'standard' OR v_scoring_type = 'rally' THEN
        -- Table Tennis deuce at 10-10
        IF v_points_to_win = 11 AND p_score_a >= 10 AND p_score_b >= 10 THEN
            -- Deuce state: need 2-point lead
            IF p_score_a - p_score_b >= 2 THEN
                RETURN 'A';
            ELSIF p_score_b - p_score_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL;
            END IF;
        END IF;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Generic scoring logic
    -- ═══════════════════════════════════════════════════════════════
    IF v_win_by_two THEN
        -- Win by 2 points
        -- Must reach points_to_win AND have 2-point lead
        
        -- Check minimum points reached
        IF p_score_a < v_points_to_win AND p_score_b < v_points_to_win THEN
            RETURN NULL; -- Neither has reached winning threshold
        END IF;

        -- Check for win by 2
        IF p_score_a >= v_points_to_win AND p_score_a - p_score_b >= 2 THEN
            RETURN 'A';
        ELSIF p_score_b >= v_points_to_win AND p_score_b - p_score_a >= 2 THEN
            RETURN 'B';
        ELSIF p_score_a >= v_points_to_win AND p_score_b >= v_points_to_win THEN
            -- Both at winning threshold but tied or 1-point lead
            RETURN NULL;
        ELSIF p_score_a >= v_points_to_win AND p_score_b < v_points_to_win - 1 THEN
            -- A won without B being able to catch up
            RETURN 'A';
        ELSIF p_score_b >= v_points_to_win AND p_score_a < v_points_to_win - 1 THEN
            -- B won without A being able to catch up
            RETURN 'B';
        ELSE
            RETURN NULL;
        END IF;
    ELSE
        -- Simple majority (not used currently, but supported)
        IF p_score_a >= v_points_to_win AND p_score_a > p_score_b THEN
            RETURN 'A';
        ELSIF p_score_b >= v_points_to_win AND p_score_b > p_score_a THEN
            RETURN 'B';
        ELSIF p_score_a >= v_points_to_win AND p_score_b >= v_points_to_win THEN
            RETURN NULL; -- Tie at winning threshold
        ELSE
            RETURN NULL;
        END IF;
    END IF;
END;
$$;


ALTER FUNCTION "public"."calculate_game_winner"("p_score_a" integer, "p_score_b" integer, "p_scoring_config" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_game_winner"("p_score_a" integer, "p_score_b" integer, "p_scoring_config" "jsonb") IS 'Returns game winner (A/B/NULL) based on scoring_config rules - handles tennis 15-30-40, deuce, golden point, standard rally scoring';



CREATE OR REPLACE FUNCTION "public"."calculate_group_standings"("p_group_id" "uuid") RETURNS TABLE("rank" integer, "member_id" "uuid", "person_id" "uuid", "matches_played" integer, "wins" integer, "losses" integer, "points_for" integer, "points_against" integer, "point_diff" integer, "total_points" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    WITH member_stats AS (
        SELECT 
            gm.id as member_id,
            gm.person_id,
            gm.entry_id,
            gm.seed,
            COUNT(DISTINCT m.id) as matches_played,
            SUM(CASE 
                WHEN (m.entry_a_id = gm.entry_id AND s.points_a > s.points_b)
                  OR (m.entry_b_id = gm.entry_id AND s.points_b > s.points_a)
                THEN 1 ELSE 0 
            END)::INTEGER as wins,
            SUM(CASE 
                WHEN (m.entry_a_id = gm.entry_id AND s.points_a < s.points_b)
                  OR (m.entry_b_id = gm.entry_id AND s.points_b < s.points_a)
                THEN 1 ELSE 0 
            END)::INTEGER as losses,
            -- Points for: sum of points scored
            COALESCE(SUM(
                CASE WHEN m.entry_a_id = gm.entry_id THEN s.points_a ELSE s.points_b END
            ), 0)::INTEGER as points_for,
            -- Points against: sum of points conceded
            COALESCE(SUM(
                CASE WHEN m.entry_a_id = gm.entry_id THEN s.points_b ELSE s.points_a END
            ), 0)::INTEGER as points_against
        FROM group_members gm
        LEFT JOIN matches m ON 
            (m.entry_a_id = gm.entry_id OR m.entry_b_id = gm.entry_id)
            AND m.group_id = p_group_id
            AND m.status = 'FINISHED'
        LEFT JOIN scores s ON m.id = s.match_id
        WHERE gm.group_id = p_group_id
        GROUP BY gm.id, gm.person_id, gm.entry_id, gm.seed
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY 
            ms.wins * 3 DESC,  -- 3 points per win
            (ms.points_for - ms.points_against) DESC,  -- Point diff
            ms.points_for DESC,  -- Points for
            ms.points_against ASC,  -- Points against
            RANDOM()  -- Tiebreaker
        )::INTEGER as rank,
        ms.member_id,
        ms.person_id,
        ms.matches_played,
        ms.wins,
        ms.losses,
        ms.points_for,
        ms.points_against,
        (ms.points_for - ms.points_against)::INTEGER as point_diff,
        (ms.wins * 3)::INTEGER as total_points
    FROM member_stats ms;
END;
$$;


ALTER FUNCTION "public"."calculate_group_standings"("p_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_set_winner"("p_sets" "jsonb", "p_scoring_config" "jsonb") RETURNS character
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    v_games_to_win INTEGER;
    v_win_by_two_games BOOLEAN;
    v_tiebreak_at INTEGER;
    v_has_tiebreak BOOLEAN;
    v_has_super_tiebreak BOOLEAN;
    v_super_tiebreak_points INTEGER;
    v_set_element JSONB;
    v_games_a INTEGER;
    v_games_b INTEGER;
    v_current_set_games_a INTEGER;
    v_current_set_games_b INTEGER;
    v_is_tb BOOLEAN;
BEGIN
    -- Handle NULL input
    IF p_sets IS NULL OR jsonb_array_length(p_sets) IS NULL OR jsonb_array_length(p_sets) = 0 THEN
        RETURN NULL;
    END IF;

    -- Extract config values
    v_games_to_win := COALESCE(p_scoring_config->>'games_to_win_set', 6)::INTEGER;
    v_win_by_two_games := COALESCE(p_scoring_config->>'win_by_two_games', 'true')::BOOLEAN;
    v_tiebreak_at := COALESCE(p_scoring_config->>'tiebreak_at', 6)::INTEGER;
    v_has_tiebreak := COALESCE(p_scoring_config->>'has_tiebreak', 'false')::BOOLEAN;
    v_has_super_tiebreak := COALESCE(p_scoring_config->>'has_super_tiebreak', 'false')::BOOLEAN;
    v_super_tiebreak_points := COALESCE(p_scoring_config->>'super_tiebreak_points', 10)::INTEGER;

    -- Iterate through all sets to count games won
    v_games_a := 0;
    v_games_b := 0;

    FOR v_set_element IN SELECT * FROM jsonb_array_elements(p_sets)
    LOOP
        -- Extract game scores from set
        -- Sets can be in format: [{"games": {"a": 6, "b": 4}}] or just [{"a": 6, "b": 4}]
        -- Check both formats for compatibility
        v_current_set_games_a := COALESCE((v_set_element->>'a')::INTEGER, (v_set_element->'games'->>'a')::INTEGER, 0);
        v_current_set_games_b := COALESCE((v_set_element->>'b')::INTEGER, (v_set_element->'games'->>'b')::INTEGER, 0);

        -- Check if this set is a tiebreak
        v_is_tb := is_tiebreak(v_current_set_games_a, v_current_set_games_b, p_scoring_config);

        IF v_is_tb THEN
            -- Tiebreak: check tiebreak points (stored in current set)
            -- For tiebreaks, we check if there's game score data
            -- The tiebreak winner is determined by points_a/points_b within the tiebreak
            -- For simplicity, we count games by who won the tiebreak
            IF v_current_set_games_a > v_current_set_games_b THEN
                v_games_a := v_games_a + 1;
            ELSIF v_current_set_games_b > v_current_set_games_a THEN
                v_games_b := v_games_b + 1;
            END IF;
        ELSIF v_current_set_games_a >= v_games_to_win OR v_current_set_games_b >= v_games_to_win THEN
            -- Normal set win - check if won by 2 if required
            IF v_win_by_two_games THEN
                IF v_current_set_games_a >= v_games_to_win 
                   AND v_current_set_games_a - v_current_set_games_b >= 2 THEN
                    v_games_a := v_games_a + 1;
                ELSIF v_current_set_games_b >= v_games_to_win 
                      AND v_current_set_games_b - v_current_set_games_a >= 2 THEN
                    v_games_b := v_games_b + 1;
                END IF;
            ELSE
                -- No win-by-two requirement
                IF v_current_set_games_a >= v_games_to_win THEN
                    v_games_a := v_games_a + 1;
                ELSIF v_current_set_games_b >= v_games_to_win THEN
                    v_games_b := v_games_b + 1;
                END IF;
            END IF;
        END IF;
    END LOOP;

    -- Check for super tiebreak (10 points win by 2 in Padel)
    IF v_has_super_tiebreak THEN
        -- Check the last set for super tiebreak scores
        v_set_element := p_sets->(jsonb_array_length(p_sets) - 1);
        v_current_set_games_a := COALESCE((v_set_element->>'a')::INTEGER, 0);
        v_current_set_games_b := COALESCE((v_set_element->>'b')::INTEGER, 0);

        -- Super tiebreak: typically at 6-6, played to 10 points win by 2
        IF v_current_set_games_a >= v_super_tiebreak_points - 1 
           AND v_current_set_games_b >= v_super_tiebreak_points - 1 THEN
            -- In super tiebreak
            IF v_current_set_games_a >= v_super_tiebreak_points 
               AND v_current_set_games_a - v_current_set_games_b >= 2 THEN
                RETURN 'A';
            ELSIF v_current_set_games_b >= v_super_tiebreak_points 
                  AND v_current_set_games_b - v_current_set_games_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL; -- Super tiebreak not complete
            END IF;
        END IF;
    END IF;

    -- Determine set winner
    IF v_games_a >= v_games_to_win THEN
        IF v_win_by_two_games THEN
            IF v_games_a - v_games_b >= 2 THEN
                RETURN 'A';
            ELSE
                RETURN NULL; -- Not won by 2 yet
            END IF;
        ELSE
            RETURN 'A';
        END IF;
    ELSIF v_games_b >= v_games_to_win THEN
        IF v_win_by_two_games THEN
            IF v_games_b - v_games_a >= 2 THEN
                RETURN 'B';
            ELSE
                RETURN NULL;
            END IF;
        ELSE
            RETURN 'B';
        END IF;
    ELSE
        RETURN NULL; -- Set not complete
    END IF;
END;
$$;


ALTER FUNCTION "public"."calculate_set_winner"("p_sets" "jsonb", "p_scoring_config" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_set_winner"("p_sets" "jsonb", "p_scoring_config" "jsonb") IS 'Returns set winner (A/B/NULL) based on game scores and scoring_config - handles tiebreaks, super tiebreaks, win-by-2 rules';



CREATE OR REPLACE FUNCTION "public"."check_offline_sync_conflict"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Block devices with fraudulently advanced time (Time-Tampering)
    IF NEW.local_updated_at > NOW() + INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'Timestamp in the future is not allowed (Time-Tampering protection)';
    END IF;

    -- If the incoming record is older than the one we already have, silently abort the update
    IF NEW.local_updated_at < OLD.local_updated_at THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_offline_sync_conflict"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_single_active_staff"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.status = 'ACTIVE' THEN
        IF EXISTS (
            SELECT 1 FROM tournament_staff
            WHERE tournament_id = NEW.tournament_id
              AND user_id = NEW.user_id
              AND status = 'ACTIVE'
              AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000')
        ) THEN
            RAISE EXCEPTION 'User already has an active staff role in this tournament';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_single_active_staff"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clear_match_referee"("p_match_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."clear_match_referee"("p_match_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."clear_match_referee"("p_match_id" "uuid") IS 'Clears referee assignment from a match. Organizer only.';



CREATE TABLE IF NOT EXISTS "public"."referee_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_id" "uuid",
    "user_id" "uuid",
    "assigned_by" "uuid",
    "is_suggested" boolean DEFAULT false,
    "is_confirmed" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "assignment_type" "public"."assignment_type" DEFAULT 'MANUAL'::"public"."assignment_type"
);


ALTER TABLE "public"."referee_assignments" OWNER TO "postgres";


COMMENT ON TABLE "public"."referee_assignments" IS 'Audit trail of referee assignments to matches';



COMMENT ON COLUMN "public"."referee_assignments"."is_suggested" IS 'True if this was auto-generated by the system';



COMMENT ON COLUMN "public"."referee_assignments"."is_confirmed" IS 'True if organizer has confirmed this assignment';



CREATE OR REPLACE FUNCTION "public"."confirm_referee_assignment"("p_match_id" "uuid", "p_user_id" "uuid" DEFAULT NULL::"uuid", "p_is_organizer_override" boolean DEFAULT false) RETURNS "public"."referee_assignments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."confirm_referee_assignment"("p_match_id" "uuid", "p_user_id" "uuid", "p_is_organizer_override" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."confirm_referee_assignment"("p_match_id" "uuid", "p_user_id" "uuid", "p_is_organizer_override" boolean) IS 'Confirms a suggested assignment or manually assigns a referee. Updates matches.referee_id.';



CREATE OR REPLACE FUNCTION "public"."create_round_robin_group"("p_tournament_id" "uuid", "p_name" "text", "p_member_entry_ids" "uuid"[], "p_advancement_count" integer DEFAULT 2) RETURNS TABLE("group_id" "uuid", "match_ids" "uuid"[])
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_group_id UUID;
    v_seed INTEGER := 1;
    v_entry_id UUID;
    v_match_id UUID;
    v_match_ids UUID[] := '{}';
    v_category_id UUID;
BEGIN
    -- Validate tournament exists and is in appropriate status
    IF NOT EXISTS (
        SELECT 1 FROM tournaments 
        WHERE id = p_tournament_id 
        AND status IN ('DRAFT', 'REGISTRATION', 'PRE_TOURNAMENT', 'CHECK_IN')
    ) THEN
        RAISE EXCEPTION 'Tournament must be in DRAFT, REGISTRATION, PRE_TOURNAMENT, or CHECK_IN status';
    END IF;
    
    -- Validate member count (read from sport config or use defaults 3-5)
    IF array_length(p_member_entry_ids, 1) < 3 THEN
        RAISE EXCEPTION 'Group must have at least 3 members';
    END IF;
    
    IF array_length(p_member_entry_ids, 1) > 5 THEN
        RAISE EXCEPTION 'Group cannot have more than 5 members (configurable in sport settings)';
    END IF;
    
    -- Validate no duplicate entries
    IF array_length(p_member_entry_ids, 1) != (SELECT COUNT(DISTINCT unnest) FROM unnest(p_member_entry_ids) AS unnest) THEN
        RAISE EXCEPTION 'Duplicate entries in member list';
    END IF;
    
    -- Get category_id from first entry
    SELECT category_id INTO v_category_id
    FROM tournament_entries
    WHERE id = p_member_entry_ids[1];
    
    -- Create group
    INSERT INTO round_robin_groups (tournament_id, name, advancement_count)
    VALUES (p_tournament_id, p_name, p_advancement_count)
    RETURNING id INTO v_group_id;
    
    -- Add members with seeding
    FOREACH v_entry_id IN ARRAY p_member_entry_ids
    LOOP
        INSERT INTO group_members (group_id, entry_id, person_id, seed)
        SELECT 
            v_group_id,
            v_entry_id,
            (SELECT person_id FROM entry_members WHERE entry_id = v_entry_id LIMIT 1),
            v_seed;
        
        v_seed := v_seed + 1;
    END LOOP;
    
    -- Generate round robin matches
    v_match_ids := generate_round_robin_matches(v_group_id);
    
    RETURN QUERY SELECT v_group_id, v_match_ids;
END;
$$;


ALTER FUNCTION "public"."create_round_robin_group"("p_tournament_id" "uuid", "p_name" "text", "p_member_entry_ids" "uuid"[], "p_advancement_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_third_place_match"("p_semi_a" "uuid", "p_semi_b" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."create_third_place_match"("p_semi_a" "uuid", "p_semi_b" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_third_place_match"("p_semi_a" "uuid", "p_semi_b" "uuid") IS 'Creates a third place match between losers of two semi-finals.
Returns the new match ID. Only organizer can call.
Both players must have accepted third place.';



CREATE OR REPLACE FUNCTION "public"."fn_track_loser_for_referee"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_winner_entry_id UUID;
    v_loser_entry_id UUID;
    v_loser_person_id UUID;
    v_loser_user_id UUID;
    v_next_match_id UUID;
    v_next_group_id UUID;
    v_current_group_id UUID;
    v_loser_referees_winner BOOLEAN;
    v_referee_mode TEXT;
    v_sport_id UUID;
BEGIN
    -- Only trigger when status changes to FINISHED
    IF OLD.status = 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status != 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    -- Get sport config to check loser_referees_winner and referee_mode
    SELECT 
        t.sport_id,
        m.group_id,
        m.entry_a_id,
        m.entry_b_id,
        m.next_match_id
    INTO v_sport_id, v_current_group_id, v_winner_entry_id, v_loser_entry_id, v_next_match_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    WHERE m.id = NEW.id;
    
    -- Check if loser_referees_winner is enabled for this sport
    SELECT 
        (scoring_config->'tournament_format'->>'loser_referees_winner')::BOOLEAN,
        scoring_config->'tournament_format'->>'referee_mode'
    INTO v_loser_referees_winner, v_referee_mode
    FROM sports
    WHERE id = v_sport_id;
    
    -- IMPORTANT: Only track if loser_referees_winner = true AND referee_mode = 'INTRA_GROUP'
    IF v_loser_referees_winner != TRUE OR v_referee_mode != 'INTRA_GROUP' THEN
        RETURN NEW;  -- Skip for sports that don't use this rule
    END IF;
    
    -- Get next match's group
    SELECT group_id INTO v_next_group_id FROM matches WHERE id = v_next_match_id;
    
    -- Determine winner/loser from score
    IF EXISTS (SELECT 1 FROM scores WHERE match_id = NEW.id) THEN
        SELECT 
            CASE 
                WHEN points_a > points_b THEN entry_a_id
                ELSE entry_b_id
            END,
            CASE 
                WHEN points_a > points_b THEN entry_b_id
                ELSE entry_a_id
            END
        INTO v_winner_entry_id, v_loser_entry_id
        FROM matches
        WHERE id = NEW.id;
    END IF;
    
    -- Get loser user_id
    SELECT p.user_id INTO v_loser_user_id
    FROM tournament_entries te
    JOIN persons p ON te.person_id = p.id
    WHERE te.id = v_loser_entry_id;
    
    IF v_loser_user_id IS NULL THEN
        RETURN NEW;  -- Shadow profile, cannot be referee
    END IF;
    
    -- Store loser for next match if there's a next match
    -- Only if same group (cross-group can't referee in INTRA_GROUP mode)
    IF v_loser_user_id IS NOT NULL AND v_next_match_id IS NOT NULL THEN
        IF v_next_group_id = v_current_group_id THEN
            UPDATE matches
            SET loser_assigned_referee = v_loser_user_id
            WHERE id = v_next_match_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_track_loser_for_referee"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_unique_person_per_tournament"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    existing_group_id UUID;
    v_tournament_id UUID;
BEGIN
    -- Get tournament_id from the group
    SELECT tournament_id INTO v_tournament_id
    FROM round_robin_groups
    WHERE id = NEW.group_id;
    
    -- Find if person is already in another group of same tournament
    SELECT gm.group_id INTO existing_group_id
    FROM group_members gm
    JOIN round_robin_groups rrg ON gm.group_id = rrg.id
    WHERE gm.person_id = NEW.person_id
    AND rrg.tournament_id = v_tournament_id
    AND gm.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
    
    IF existing_group_id IS NOT NULL THEN
        RAISE EXCEPTION 'Person % is already in a group for this tournament', NEW.person_id;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_unique_person_per_tournament"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_unique_seed_per_group"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    existing_seed INTEGER;
BEGIN
    SELECT seed INTO existing_seed
    FROM group_members
    WHERE group_id = NEW.group_id
    AND seed = NEW.seed
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
    
    IF existing_seed IS NOT NULL THEN
        RAISE EXCEPTION 'Seed % already exists in group %', NEW.seed, NEW.group_id;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_unique_seed_per_group"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_update_group_status_on_match_complete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_group_id UUID;
    v_pending_matches INTEGER;
    v_group_status group_status;
BEGIN
    -- Only trigger on status change to FINISHED or W_O
    IF OLD.status IN ('FINISHED', 'W_O') THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status NOT IN ('FINISHED', 'W_O') THEN
        RETURN NEW;
    END IF;
    
    -- Get group_id from match
    SELECT group_id INTO v_group_id FROM matches WHERE id = NEW.id;
    
    IF v_group_id IS NULL THEN
        RETURN NEW;  -- Not a group match, skip
    END IF;
    
    -- Count pending matches in group
    SELECT COUNT(*) INTO v_pending_matches
    FROM matches
    WHERE group_id = v_group_id
    AND status NOT IN ('FINISHED', 'W_O', 'CANCELLED');
    
    -- Update group status
    IF v_pending_matches = 0 THEN
        UPDATE round_robin_groups
        SET status = 'COMPLETED', updated_at = NOW()
        WHERE id = v_group_id;
    ELSE
        -- Check if group is still PENDING, change to IN_PROGRESS
        SELECT status INTO v_group_status FROM round_robin_groups WHERE id = v_group_id;
        IF v_group_status = 'PENDING' THEN
            UPDATE round_robin_groups
            SET status = 'IN_PROGRESS', updated_at = NOW()
            WHERE id = v_group_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_update_group_status_on_match_complete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_update_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_update_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_validate_group_member_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    current_count INTEGER;
    max_members INTEGER;
    v_sport_id UUID;
    v_scoring_config JSONB;
BEGIN
    -- Get sport config for this tournament
    SELECT t.sport_id, s.scoring_config
    INTO v_sport_id, v_scoring_config
    FROM round_robin_groups rrg
    JOIN tournaments t ON rrg.tournament_id = t.id
    JOIN sports s ON t.sport_id = s.id
    WHERE rrg.id = NEW.group_id;
    
    -- Read max from config, default to 5 if not set
    max_members := COALESCE(
        (v_scoring_config->'tournament_format'->'group_size'->>'max')::INTEGER,
        5
    );
    
    -- Get current member count (excluding the one being updated/deleted)
    IF TG_OP = 'DELETE' THEN
        SELECT COUNT(*) INTO current_count
        FROM group_members
        WHERE group_id = OLD.group_id;
    ELSE
        SELECT COUNT(*) INTO current_count
        FROM group_members
        WHERE group_id = NEW.group_id
        AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
    END IF;
    
    IF current_count >= max_members AND TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'Group cannot have more than % members (configured in sport)', max_members;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_validate_group_member_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_validate_referee_assignment"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_match_group_id UUID;
    v_match_entry_a UUID;
    v_match_entry_b UUID;
    v_referee_person_id UUID;
    v_match_phase match_phase;
    v_referee_mode TEXT;
    v_sport_id UUID;
    v_scoring_config JSONB;
BEGIN
    -- Get match info
    SELECT 
        m.group_id,
        m.entry_a_id,
        m.entry_b_id,
        m.phase,
        t.sport_id
    INTO v_match_group_id, v_match_entry_a, v_match_entry_b, v_match_phase, v_sport_id
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    WHERE m.id = NEW.match_id;
    
    -- Get referee_mode from sport config
    SELECT scoring_config->'tournament_format'->>'referee_mode'
    INTO v_referee_mode
    FROM sports
    WHERE id = v_sport_id;
    
    -- Get scoring config for loser_referees_winner check
    SELECT scoring_config INTO v_scoring_config FROM sports WHERE id = v_sport_id;
    
    -- If no group (bracket match), skip validation
    IF v_match_group_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- If not ROUND_ROBIN phase, skip (KO allows different referee rules)
    IF v_match_phase != 'ROUND_ROBIN' THEN
        RETURN NEW;
    END IF;
    
    -- IMPORTANT: Only enforce intra-group rule if referee_mode = 'INTRA_GROUP'
    -- For other modes (NONE, EXTERNAL, ROTATING), skip this validation
    IF v_referee_mode != 'INTRA_GROUP' THEN
        RETURN NEW;  -- Skip validation for non-intra-group modes
    END IF;
    
    -- Get referee's person_id from user_id
    SELECT p.id INTO v_referee_person_id
    FROM auth.users au
    JOIN persons p ON au.id = p.user_id
    WHERE au.id = NEW.user_id;
    
    IF v_referee_person_id IS NULL THEN
        RAISE EXCEPTION 'Referee must have a user account';
    END IF;
    
    -- Validate referee is in same group
    IF NOT EXISTS (
        SELECT 1 FROM group_members gm
        WHERE gm.group_id = v_match_group_id
        AND gm.person_id = v_referee_person_id
    ) THEN
        RAISE EXCEPTION 'Referee must be from the same group (referee_mode=INTRA_GROUP)';
    END IF;
    
    -- Validate referee is not playing (entry not in match)
    IF EXISTS (
        SELECT 1 FROM group_members gm
        JOIN tournament_entries te ON gm.entry_id = te.id
        WHERE gm.group_id = v_match_group_id
        AND gm.person_id = v_referee_person_id
        AND te.id IN (v_match_entry_a, v_match_entry_b)
    ) THEN
        RAISE EXCEPTION 'Referee cannot be one of the players';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_validate_referee_assignment"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_bracket"("p_category_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."generate_bracket"("p_category_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_bracket_from_groups"("p_tournament_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_bracket_id UUID;
    v_group_ids UUID[];
    v_slot_position INTEGER := 1;
    v_round INTEGER := 1;
    v_slots_per_round INTEGER;
    v_total_slots INTEGER;
    v_i INTEGER;
    v_group_count INTEGER;
BEGIN
    -- Validate all groups are COMPLETED
    IF EXISTS (
        SELECT 1 FROM round_robin_groups
        WHERE tournament_id = p_tournament_id
        AND status != 'COMPLETED'
    ) THEN
        RAISE EXCEPTION 'All groups must be COMPLETED before generating bracket';
    END IF;
    
    -- Check no bracket exists
    IF EXISTS (
        SELECT 1 FROM knockout_brackets
        WHERE tournament_id = p_tournament_id
    ) THEN
        RAISE EXCEPTION 'Bracket already exists for this tournament';
    END IF;
    
    -- Create bracket
    INSERT INTO knockout_brackets (tournament_id)
    VALUES (p_tournament_id)
    RETURNING id INTO v_bracket_id;
    
    -- Get all groups ordered by name
    SELECT ARRAY_AGG(id ORDER BY name) INTO v_group_ids
    FROM round_robin_groups
    WHERE tournament_id = p_tournament_id;
    
    v_group_count := array_length(v_group_ids, 1);
    
    -- Calculate total qualifiers
    SELECT 
        SUM(advancement_count)::INTEGER INTO v_total_slots
    FROM round_robin_groups
    WHERE tournament_id = p_tournament_id;
    
    -- Round up to power of 2
    v_total_slots := pow(2, ceil(log(2, v_total_slots::numeric)))::INTEGER;
    
    -- First round slots = v_total_slots
    v_slots_per_round := v_total_slots;
    v_round := 1;
    
    -- Create first round slots (qualifiers from groups)
    FOR v_i IN 1..v_total_slots LOOP
        DECLARE
            v_group_idx INTEGER := ((v_i - 1) / (v_total_slots / v_group_count)) + 1;
            v_position_in_group INTEGER := ((v_i - 1) % (v_total_slots / v_group_count)) + 1;
            v_entry_id UUID;
            v_seed_source TEXT;
            v_round_name TEXT;
        BEGIN
            -- Get entry_id based on position in group
            SELECT 
                gm.entry_id,
                rrg.name || '_' || gm.seed
            INTO v_entry_id, v_seed_source
            FROM round_robin_groups rrg
            JOIN group_members gm ON gm.group_id = rrg.id
            WHERE rrg.id = v_group_ids[GREATEST(1, LEAST(v_group_idx, v_group_count))]
            AND gm.seed = v_position_in_group;
            
            -- Determine round name
            IF v_slots_per_round = 2 THEN
                v_round_name := 'Final';
            ELSIF v_slots_per_round = 4 THEN
                v_round_name := 'Semifinals';
            ELSIF v_slots_per_round >= 8 THEN
                v_round_name := 'Quarterfinals';
            ELSE
                v_round_name := 'Round ' || v_round;
            END IF;
            
            INSERT INTO bracket_slots (
                bracket_id,
                position,
                round,
                round_name,
                entry_id,
                seed_source
            )
            VALUES (
                v_bracket_id,
                v_slot_position,
                v_round,
                v_round_name,
                v_entry_id,
                v_seed_source
            );
            
            v_slot_position := v_slot_position + 1;
        END;
    END LOOP;
    
    -- Create subsequent rounds (empty slots)
    WHILE v_slots_per_round > 1 LOOP
        v_slots_per_round := v_slots_per_round / 2;
        v_round := v_round + 1;
        
        FOR v_i IN 1..v_slots_per_round LOOP
            INSERT INTO bracket_slots (
                bracket_id,
                position,
                round,
                round_name,
                entry_id
            )
            VALUES (
                v_bracket_id,
                v_slot_position,
                v_round,
                CASE 
                    WHEN v_slots_per_round = 1 THEN 'Final'
                    WHEN v_slots_per_round = 2 THEN 'Semifinals'
                    ELSE 'Round ' || v_round
                END,
                NULL
            );
            
            v_slot_position := v_slot_position + 1;
        END LOOP;
    END LOOP;
    
    RETURN v_bracket_id;
END;
$$;


ALTER FUNCTION "public"."generate_bracket_from_groups"("p_tournament_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_feed_event"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_tournament_id UUID;
    v_payload JSONB;
BEGIN
    -- Determine tournament_id based on context
    IF TG_TABLE_NAME = 'tournament_entries' THEN
        SELECT c.tournament_id INTO v_tournament_id
        FROM categories c
        JOIN tournament_entries te ON te.category_id = c.id
        WHERE te.id = NEW.id;
        
        -- Entry registered event
        IF NEW.status = 'CONFIRMED' THEN
            INSERT INTO community_feed (tournament_id, event_type, payload_json)
            VALUES (v_tournament_id, 'ENTRY_REGISTERED', 
                jsonb_build_object(
                    'entry_id', NEW.id,
                    'display_name', NEW.display_name
                ));
        ELSIF NEW.status = 'CANCELLED' THEN
            INSERT INTO community_feed (tournament_id, event_type, payload_json)
            VALUES (v_tournament_id, 'ENTRY_CANCELLED',
                jsonb_build_object(
                    'entry_id', NEW.id,
                    'display_name', NEW.display_name
                ));
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."generate_feed_event"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_match_pin"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Generate a random 4-digit number, padded with leading zeros
    NEW.pin_code := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."generate_match_pin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_referee_suggestions"("p_category_id" "uuid") RETURNS TABLE("match_id" "uuid", "user_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."generate_referee_suggestions"("p_category_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."generate_referee_suggestions"("p_category_id" "uuid") IS 'Generates auto-suggestions for referee assignments using round-robin balancing.';



CREATE OR REPLACE FUNCTION "public"."generate_round_robin_matches"("p_group_id" "uuid") RETURNS "uuid"[]
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_member_ids UUID[];
    v_match_ids UUID[] := '{}';
    v_i INTEGER;
    v_j INTEGER;
    v_entry_a UUID;
    v_entry_b UUID;
    v_match_id UUID;
    v_round INTEGER := 1;
    v_match_count INTEGER := 0;
    v_category_id UUID;
BEGIN
    -- Get category_id from group
    SELECT te.category_id INTO v_category_id
    FROM round_robin_groups rrg
    JOIN group_members gm ON gm.group_id = rrg.id
    JOIN tournament_entries te ON te.id = gm.entry_id
    WHERE rrg.id = p_group_id
    LIMIT 1;
    
    -- Get all member entry_ids ordered by seed
    SELECT ARRAY_AGG(entry_id ORDER BY seed)
    INTO v_member_ids
    FROM group_members
    WHERE group_id = p_group_id;
    
    -- Generate matches using round-robin circular algorithm
    FOR v_i IN 1..array_length(v_member_ids, 1) LOOP
        FOR v_j IN (v_i + 1)..array_length(v_member_ids, 1) LOOP
            v_entry_a := v_member_ids[v_i];
            v_entry_b := v_member_ids[v_j];
            
            v_match_count := v_match_count + 1;
            
            -- Calculate round (2 matches per round for better scheduling)
            v_round := ceil(v_match_count::DECIMAL / 2)::INTEGER;
            
            INSERT INTO matches (
                group_id,
                category_id,
                entry_a_id,
                entry_b_id,
                round_number,
                status,
                phase
            )
            VALUES (
                p_group_id,
                v_category_id,
                v_entry_a,
                v_entry_b,
                v_round,
                'SCHEDULED',
                'ROUND_ROBIN'
            )
            RETURNING id INTO v_match_id;
            
            v_match_ids := array_append(v_match_ids, v_match_id);
        END LOOP;
    END LOOP;
    
    -- Link matches in sequence (next_match_of_winner)
    FOR v_i IN 1..array_length(v_match_ids, 1) - 1 LOOP
        UPDATE matches
        SET next_match_id = v_match_ids[v_i + 1]
        WHERE id = v_match_ids[v_i];
    END LOOP;
    
    RETURN v_match_ids;
END;
$$;


ALTER FUNCTION "public"."generate_round_robin_matches"("p_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_available_referees"("p_match_id" "uuid") RETURNS TABLE("user_id" "uuid", "person_id" "uuid", "display_name" "text", "matches_refereed" integer, "is_available" boolean, "reason_unavailable" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_group_id UUID;
    v_entry_a_id UUID;
    v_entry_b_id UUID;
BEGIN
    -- Get match info
    SELECT group_id, entry_a_id, entry_b_id
    INTO v_group_id, v_entry_a_id, v_entry_b_id
    FROM matches
    WHERE id = p_match_id;
    
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Match is not part of a Round Robin group';
    END IF;
    
    RETURN QUERY
    WITH group_players AS (
        SELECT 
            gm.person_id,
            gm.entry_id,
            gm.seed,
            gm.status,
            gm.check_in_at
        FROM group_members gm
        WHERE gm.group_id = v_group_id
    ),
    player_users AS (
        SELECT 
            p.id as person_id,
            au.id as user_id,
            p.first_name || ' ' || COALESCE(p.last_name, '') as display_name,
            gp.entry_id,
            gp.seed,
            gp.status,
            gp.check_in_at,
            COALESCE(ast.matches_refereed, 0) as matches_refereed
        FROM group_players gp
        JOIN persons p ON gp.person_id = p.id
        JOIN auth.users au ON p.user_id = au.id
        LEFT JOIN athlete_stats ast ON p.id = ast.person_id
        WHERE p.user_id IS NOT NULL  -- Must have user account
    )
    SELECT 
        pu.user_id,
        pu.person_id,
        pu.display_name,
        pu.matches_refereed,
        CASE 
            WHEN pu.entry_id IN (v_entry_a_id, v_entry_b_id) THEN FALSE
            WHEN pu.status != 'ACTIVE' THEN FALSE
            WHEN pu.check_in_at IS NULL THEN FALSE
            ELSE TRUE
        END as is_available,
        CASE 
            WHEN pu.entry_id IN (v_entry_a_id, v_entry_b_id) THEN 'Playing in this match'
            WHEN pu.status != 'ACTIVE' THEN 'Not active in group'
            WHEN pu.check_in_at IS NULL THEN 'Not checked in'
            ELSE NULL
        END as reason_unavailable
    FROM player_users pu
    ORDER BY 
        CASE WHEN is_available THEN 0 ELSE 1 END,
        pu.matches_refereed ASC,
        RANDOM();
    
END;
$$;


ALTER FUNCTION "public"."get_available_referees"("p_match_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_match_loser"("p_match_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
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


ALTER FUNCTION "public"."get_match_loser"("p_match_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_match_loser"("p_match_id" "uuid") IS 'Returns the entry_id of the loser from a match based on scores.
Returns NULL if match not finished or scores are tied.';



CREATE OR REPLACE FUNCTION "public"."inherit_tournament_country"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_club_country_id UUID;
BEGIN
    -- Only try if country is not already set
    IF NEW.country_id IS NULL THEN
        -- Try to find the associated club via the organizer or tournament entry
        -- Since tournaments are often started by staff belonging to a club, 
        -- we can lookup the club tied to the tournament (if exists via a staff member)
        -- Simplified for now: Manual entry in MVP or auto-filled via App.
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."inherit_tournament_country"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invite_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text") RETURNS "public"."tournament_staff"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN assign_staff(p_tournament_id, p_user_id, p_role, TRUE);
END;
$$;


ALTER FUNCTION "public"."invite_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."invite_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text") IS 'Convenience wrapper for assign_staff with invite_mode=true.';



CREATE OR REPLACE FUNCTION "public"."is_tiebreak"("p_game_a" integer, "p_game_b" integer, "p_scoring_config" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    v_tiebreak_at INTEGER;
    v_has_tiebreak BOOLEAN;
BEGIN
    v_has_tiebreak := COALESCE(p_scoring_config->>'has_tiebreak', 'false')::BOOLEAN;
    v_tiebreak_at := COALESCE(p_scoring_config->>'tiebreak_at', 6)::INTEGER;

    -- No tiebreak if feature is disabled
    IF NOT v_has_tiebreak THEN
        RETURN FALSE;
    END IF;

    -- Tiebreak occurs when both players reach tiebreak_at (e.g., 6-6 in tennis)
    RETURN p_game_a = v_tiebreak_at AND p_game_b = v_tiebreak_at;
END;
$$;


ALTER FUNCTION "public"."is_tiebreak"("p_game_a" integer, "p_game_b" integer, "p_scoring_config" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_tiebreak"("p_game_a" integer, "p_game_b" integer, "p_scoring_config" "jsonb") IS 'Helper: Returns TRUE if game scores indicate a tiebreak situation (e.g., 6-6 in tennis)';



CREATE OR REPLACE FUNCTION "public"."manage_sports"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Only allow if called from service role context or admin check
    -- For MVP: we use a simple check that this is an admin operation
    IF current_setting('app.role', true) = 'admin' THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Only administrators can modify sports';
END;
$$;


ALTER FUNCTION "public"."manage_sports"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."offer_third_place"("p_match_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."offer_third_place"("p_match_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."offer_third_place"("p_match_id" "uuid") IS 'Organizer offers third place to players after a semi-final match ends.
Returns TRUE if successful. Raises exception if invalid state or permission denied.';



CREATE OR REPLACE FUNCTION "public"."prevent_duplicate_registration"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_category_tournament_id UUID;
    v_existing_count INTEGER;
BEGIN
    -- Get tournament_id from the category of the entry being registered to
    SELECT c.tournament_id INTO v_category_tournament_id
    FROM categories c
    JOIN tournament_entries te ON te.category_id = c.id
    WHERE te.id = NEW.entry_id;

    -- Check if person already has an active registration (non-cancelled) in this tournament
    SELECT COUNT(*) INTO v_existing_count
    FROM entry_members em
    JOIN tournament_entries te ON em.entry_id = te.id
    JOIN categories c ON te.category_id = c.id
    WHERE em.person_id = NEW.person_id
      AND c.tournament_id = v_category_tournament_id
      AND te.status != 'CANCELLED';

    IF v_existing_count > 0 THEN
        RAISE EXCEPTION 'Person % is already registered in this tournament', NEW.person_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_duplicate_registration"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_match_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
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
$$;


ALTER FUNCTION "public"."process_match_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reject_invitation"("p_tournament_id" "uuid") RETURNS "public"."tournament_staff"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."reject_invitation"("p_tournament_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."reject_invitation"("p_tournament_id" "uuid") IS 'Rejects a pending staff invitation.';



CREATE OR REPLACE FUNCTION "public"."revoke_staff"("p_tournament_id" "uuid", "p_target_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."revoke_staff"("p_tournament_id" "uuid", "p_target_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."revoke_staff"("p_tournament_id" "uuid", "p_target_user_id" "uuid") IS 'Revokes a staff member access. Organizer cannot revoke themselves.';



CREATE OR REPLACE FUNCTION "public"."rollback_match"("p_match_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_match matches%ROWTYPE;
BEGIN
    SELECT * INTO v_match FROM matches WHERE id = p_match_id;
    
    -- Validate that the executor is an ORGANIZER
    IF NOT EXISTS (
        SELECT 1 FROM categories c
        JOIN tournament_staff ts ON c.tournament_id = ts.tournament_id
        WHERE c.id = v_match.category_id AND ts.user_id = auth.uid() AND ts.role = 'ORGANIZER'
    ) THEN
        RAISE EXCEPTION 'Access Denied: Only ORGANIZER can rollback matches.';
    END IF;

    -- Revert state to LIVE
    UPDATE matches SET status = 'LIVE' WHERE id = p_match_id;

    -- Clear bracket of projected winner
    IF v_match.next_match_id IS NOT NULL THEN
        UPDATE matches SET entry_a_id = NULL WHERE id = v_match.next_match_id AND entry_a_id IN (v_match.entry_a_id, v_match.entry_b_id);
        UPDATE matches SET entry_b_id = NULL WHERE id = v_match.next_match_id AND entry_b_id IN (v_match.entry_a_id, v_match.entry_b_id);
    END IF;

    -- Accounting logic for ELO_HISTORY return (pseudo)
    -- INSERT INTO elo_history (match_id, previous_elo, new_elo) SELECT ..., -delta FROM elo_history WHERE match_id = p_match_id;
END;
$$;


ALTER FUNCTION "public"."rollback_match"("p_match_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."suggest_intra_group_referee"("p_match_id" "uuid") RETURNS TABLE("user_id" "uuid", "assignment_type" "text", "reason" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_group_id UUID;
    v_entry_a_id UUID;
    v_entry_b_id UUID;
    v_loser_user_id UUID;
    v_bye_member_id UUID;
BEGIN
    -- Get match info
    SELECT group_id, entry_a_id, entry_b_id, loser_assigned_referee
    INTO v_group_id, v_entry_a_id, v_entry_b_id, v_loser_user_id
    FROM matches
    WHERE id = p_match_id;
    
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Match is not part of a Round Robin group';
    END IF;
    
    -- Priority 1: Loser of previous match (BR-LOSER-001)
    IF v_loser_user_id IS NOT NULL THEN
        -- Verify loser is in same group and not playing
        IF EXISTS (
            SELECT 1 FROM group_members gm
            JOIN tournament_entries te ON gm.entry_id = te.id
            JOIN persons p ON te.person_id = p.id
            WHERE gm.group_id = v_group_id
            AND p.user_id = v_loser_user_id
            AND gm.entry_id NOT IN (v_entry_a_id, v_entry_b_id)
            AND gm.status = 'ACTIVE'
        ) THEN
            RETURN QUERY SELECT v_loser_user_id, 'LOSER_ASSIGNED'::TEXT, 
                'Loser of previous match has priority'::TEXT;
            RETURN;
        END IF;
    END IF;
    
    -- Priority 2: Member with BYE in current round
    SELECT au.id INTO v_bye_member_id
    FROM group_members gm
    JOIN tournament_entries te ON gm.entry_id = te.id
    JOIN persons p ON te.person_id = p.id
    JOIN auth.users au ON p.user_id = au.id
    WHERE gm.group_id = v_group_id
    AND gm.round_bye = (SELECT round_number FROM matches WHERE id = p_match_id)
    AND gm.entry_id NOT IN (v_entry_a_id, v_entry_b_id)
    AND gm.status = 'ACTIVE'
    AND gm.check_in_at IS NOT NULL
    LIMIT 1;
    
    IF v_bye_member_id IS NOT NULL THEN
        RETURN QUERY SELECT v_bye_member_id, 'AUTOMATIC'::TEXT, 
            'Member has BYE this round'::TEXT;
        RETURN;
    END IF;
    
    -- Priority 3: Member with fewest referee assignments (round-robin)
    RETURN QUERY
    SELECT 
        au.id,
        'AUTOMATIC'::TEXT,
        'Least matches refereed'::TEXT
    FROM group_members gm
    JOIN tournament_entries te ON gm.entry_id = te.id
    JOIN persons p ON te.person_id = p.id
    JOIN auth.users au ON p.user_id = au.id
    LEFT JOIN referee_assignments ra ON au.id = ra.user_id
    WHERE gm.group_id = v_group_id
    AND gm.entry_id NOT IN (v_entry_a_id, v_entry_b_id)
    AND gm.status = 'ACTIVE'
    AND gm.check_in_at IS NOT NULL
    GROUP BY au.id
    ORDER BY COUNT(ra.id) ASC, RANDOM()
    LIMIT 1;
    
END;
$$;


ALTER FUNCTION "public"."suggest_intra_group_referee"("p_match_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_referee_volunteer"("p_tournament_id" "uuid", "p_is_active" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."toggle_referee_volunteer"("p_tournament_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."toggle_referee_volunteer"("p_tournament_id" "uuid", "p_is_active" boolean) IS 'Toggles player referee volunteer status. Requires check-in.';



CREATE OR REPLACE FUNCTION "public"."trg_validate_score"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_valid BOOLEAN;
BEGIN
    -- Skip validation if match_id is NULL (allowing row creation without match)
    IF NEW.match_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Validate current set scores (points_a and points_b)
    v_valid := validate_score(
        NEW.match_id,
        NEW.points_a,
        NEW.points_b
    );

    -- If validation passes, v_valid is TRUE; otherwise exception was raised
    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid score values for match %', NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_validate_score"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_athlete_rank"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.rank := CASE
        WHEN NEW.current_elo <= 1000 THEN 'BRONZE'::athlete_rank
        WHEN NEW.current_elo <= 1200 THEN 'SILVER'::athlete_rank
        WHEN NEW.current_elo <= 1400 THEN 'GOLD'::athlete_rank
        WHEN NEW.current_elo <= 1600 THEN 'PLATINUM'::athlete_rank
        ELSE 'DIAMOND'::athlete_rank
    END;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_athlete_rank"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_referee_stats"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.is_confirmed = TRUE AND OLD.is_confirmed = FALSE THEN
        -- Increment matches_refereed for the referee
        UPDATE athlete_stats
        SET matches_refereed = matches_refereed + 1
        WHERE person_id = (
            SELECT id FROM persons WHERE user_id = NEW.user_id
        );
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_referee_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_attendance_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_tournament_status tournament_status;
    v_has_matches BOOLEAN;
BEGIN
    -- Get tournament status
    SELECT t.status INTO v_tournament_status
    FROM tournaments t
    JOIN categories c ON c.tournament_id = t.id
    WHERE c.id = NEW.category_id;

    -- Check if tournament is already LIVE (bracket generated)
    IF v_tournament_status = 'LIVE' THEN
        RAISE EXCEPTION 'Cannot change attendance after tournament has started';
    END IF;

    -- If marking as not attended, set status to CANCELLED
    IF OLD.status = 'CONFIRMED' AND NEW.status = 'CANCELLED' THEN
        -- Setting checked_in_at to NULL indicates not attended
        NEW.checked_in_at := NULL;
    END IF;

    -- If marking as attended, set checked_in_at timestamp
    IF NEW.checked_in_at IS NOT NULL AND OLD.checked_in_at IS NULL THEN
        NEW.status := 'CONFIRMED';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_attendance_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_category_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tournament_entries te
        WHERE te.category_id = OLD.id
    ) THEN
        RAISE EXCEPTION 'Cannot delete category with registered entries';
    END IF;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."validate_category_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_match_entry"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_is_staff BOOLEAN;
    v_tournament_id UUID;
    v_match_pin TEXT;
BEGIN
    -- Get tournament context
    SELECT c.tournament_id, m.pin_code
    INTO v_tournament_id, v_match_pin
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    WHERE m.id = NEW.id;

    -- Check if current user is Staff (ORGANIZER or REFEREE)
    -- In Supabase, auth.uid() provides the current user
    SELECT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = v_tournament_id
          AND user_id = auth.uid()
    ) INTO v_is_staff;

    -- If not staff, enforce PIN check
    -- The player must send the PIN in a CUSTOM metadata or a temporary field?
    -- Strategy: We use a SESSION VARIABLE 'request.jwt.claims' -> 'pin_code' (set by client)
    -- Or for now, we assume the app includes the PIN in a column update 'last_pin_attempt'
    
    -- NOTE: In a real app, you would use an RPC call.
    -- For this prototype, we will allow the update IF v_is_staff OR the action comes from a trusted source.
    -- TODO: Refine this validation logic for production.
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_match_entry"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_score"("p_match_id" "uuid", "p_points_a" integer, "p_points_b" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_scoring_config JSONB;
    v_points_per_set INTEGER;
    v_win_by_2 BOOLEAN;
    v_tiebreak_at INTEGER;
    v_tiebreak_points INTEGER;
    v_golden_point BOOLEAN;
    v_min_difference INTEGER;
    v_max_points INTEGER;
    v_winner_a BOOLEAN;
    v_winner_points INTEGER;
    v_loser_points INTEGER;
BEGIN
    -- Get scoring_config from match's sport (via category -> tournament -> sport)
    SELECT COALESCE(s.scoring_config, 
        jsonb_build_object(
            'points_per_set', COALESCE(s.default_points_per_set, 11),
            'win_by_2', true,
            'tie_break', jsonb_build_object('enabled', true, 'points', 7),
            'golden_point', jsonb_build_object('enabled', true, 'min_difference', 2)
        )
    ) INTO v_scoring_config
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    JOIN sports s ON t.sport_id = s.id
    WHERE m.id = p_match_id;

    -- Extract scoring parameters with defaults
    v_points_per_set := COALESCE(
        (v_scoring_config->>'points_per_set')::INTEGER,
        11
    );
    
    v_win_by_2 := COALESCE(
        (v_scoring_config->>'win_by_2')::BOOLEAN,
        TRUE
    );
    
    v_tiebreak_at := COALESCE(
        (v_scoring_config->'tie_break'->>'at')::INTEGER,
        10
    );
    
    v_tiebreak_points := COALESCE(
        (v_scoring_config->'tie_break'->>'points')::INTEGER,
        7
    );
    
    v_golden_point := COALESCE(
        (v_scoring_config->'golden_point'->>'enabled')::BOOLEAN,
        TRUE
    );
    
    v_min_difference := COALESCE(
        (v_scoring_config->'golden_point'->>'min_difference')::INTEGER,
        (v_scoring_config->>'min_difference')::INTEGER,
        2
    );

    -- Calculate max valid points (for win-by-2, we allow going beyond points_per_set)
    v_max_points := v_points_per_set + v_min_difference + 10;

    -- Validate score ranges
    IF p_points_a < 0 OR p_points_b < 0 THEN
        RAISE EXCEPTION 'Score cannot be negative. Got: points_a=%, points_b=%', p_points_a, p_points_b;
    END IF;

    -- Allow 0-0 as initial state (game not started)
    IF p_points_a = 0 AND p_points_b = 0 THEN
        RETURN TRUE;
    END IF;

    IF p_points_a > v_max_points OR p_points_b > v_max_points THEN
        RAISE EXCEPTION 'Score exceeds maximum allowed (%). Got: points_a=%, points_b=%', v_max_points, p_points_a, p_points_b;
    END IF;

    -- Determine winner and calculate difference
    IF p_points_a > p_points_b THEN
        v_winner_a := TRUE;
        v_winner_points := p_points_a;
        v_loser_points := p_points_b;
    ELSIF p_points_b > p_points_a THEN
        v_winner_a := FALSE;
        v_winner_points := p_points_b;
        v_loser_points := p_points_a;
    ELSE
        -- Tie scores are invalid (except in specific tiebreak scenarios)
        RAISE EXCEPTION 'Scores cannot be tied. Each player must have a different score.';
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Edge Case: TIEBREAK / GOLDEN POINT detection
    -- ═══════════════════════════════════════════════════════════════
    -- Golden point: When BOTH players reach tiebreak_at (e.g., 10-10 in Padel)
    -- At that point, winning requires 2 point lead but can go beyond points_per_set
    -- Examples: 12-10, 13-11, 14-12 (valid) vs 11-10 (invalid - not enough lead)
    IF v_golden_point AND p_points_a >= v_tiebreak_at AND p_points_b >= v_tiebreak_at THEN
        -- Golden point scenario: winner just needs min_difference lead
        IF v_winner_points >= v_loser_points + v_min_difference THEN
            RETURN TRUE; -- Valid golden point score (e.g., 12-10, 14-12)
        ELSE
            RAISE EXCEPTION 
                'Invalid golden point score. In golden point (at %-%), winner must lead by at least % points. Got: %-%',
                v_tiebreak_at, v_tiebreak_at, v_min_difference, p_points_a, p_points_b;
        END IF;
    END IF;

    -- ═══════════════════════════════════════════════════════════════
    -- Standard scoring validation (win by 2 rule)
    -- ═══════════════════════════════════════════════════════════════
    IF v_win_by_2 THEN
        -- Winner must have at least points_per_set AND lead by 2+
        IF v_winner_points >= v_points_per_set AND v_winner_points >= v_loser_points + v_min_difference THEN
            RETURN TRUE;
        ELSIF v_winner_points >= v_points_per_set THEN
            RAISE EXCEPTION 
                'Invalid score: Win by % rule requires winner to have at least % points and lead by %. Got: %-%',
                v_min_difference, v_points_per_set, v_min_difference, p_points_a, p_points_b;
        ELSE
            RAISE EXCEPTION 
                'Invalid score: Winner must reach at least % points. Got: %-%',
                v_points_per_set, p_points_a, p_points_b;
        END IF;
    ELSE
        -- No win-by-2 required (some formats like boxing)
        -- Winner just needs to reach points_per_set
        IF v_winner_points >= v_points_per_set THEN
            RETURN TRUE;
        ELSE
            RAISE EXCEPTION 
                'Invalid score: Winner must reach at least % points. Got: %-%',
                v_points_per_set, p_points_a, p_points_b;
        END IF;
    END IF;
END;
$$;


ALTER FUNCTION "public"."validate_score"("p_match_id" "uuid", "p_points_a" integer, "p_points_b" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."validate_score"("p_match_id" "uuid", "p_points_a" integer, "p_points_b" integer) IS 'Validates a score for a match based on the sport''s scoring configuration.
Returns TRUE if valid, raises exception if invalid.
Handles: win-by-2 rule, tiebreak detection, golden point (Padel/TT at 10-10).';



CREATE TABLE IF NOT EXISTS "public"."achievements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "icon_slug" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."athlete_stats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "person_id" "uuid",
    "sport_id" "uuid",
    "current_elo" integer DEFAULT 1000,
    "matches_played" integer DEFAULT 0,
    "rank" "public"."athlete_rank" DEFAULT 'BRONZE'::"public"."athlete_rank",
    "matches_refereed" integer DEFAULT 0
);


ALTER TABLE "public"."athlete_stats" OWNER TO "postgres";


COMMENT ON COLUMN "public"."athlete_stats"."matches_refereed" IS 'Total matches refereed by this player (for round-robin balancing)';



CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid",
    "name" "text" NOT NULL,
    "mode" "public"."game_mode" DEFAULT 'SINGLES'::"public"."game_mode",
    "points_override" integer,
    "sets_override" integer,
    "elo_min" integer,
    "elo_max" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "bracket_generated" boolean DEFAULT false
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entry_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entry_id" "uuid",
    "person_id" "uuid"
);


ALTER TABLE "public"."entry_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."matches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category_id" "uuid",
    "entry_a_id" "uuid",
    "entry_b_id" "uuid",
    "referee_id" "uuid",
    "court_id" "text",
    "status" "public"."match_status" DEFAULT 'SCHEDULED'::"public"."match_status",
    "next_match_id" "uuid",
    "round_name" "text",
    "started_at" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "local_updated_at" timestamp with time zone,
    "winner_to_slot" "public"."bracket_slot",
    "loser_to_slot" "public"."bracket_slot",
    "pin_code" "text",
    "third_place_pending" boolean DEFAULT false,
    "third_place_accepted" boolean,
    "group_id" "uuid",
    "bracket_id" "uuid",
    "phase" "public"."match_phase" DEFAULT 'ROUND_ROBIN'::"public"."match_phase",
    "round_number" integer,
    "loser_assigned_referee" "uuid"
);


ALTER TABLE "public"."matches" OWNER TO "postgres";


COMMENT ON COLUMN "public"."matches"."next_match_id" IS 'The next match the WINNER will play';



COMMENT ON COLUMN "public"."matches"."winner_to_slot" IS 'Identifies which slot (A or B) the winner advances to in the next_match_id.';



COMMENT ON COLUMN "public"."matches"."third_place_pending" IS 'When TRUE, third place has been offered to players in this match';



COMMENT ON COLUMN "public"."matches"."third_place_accepted" IS 'NULL = no response, TRUE = accepted, FALSE = rejected';



COMMENT ON COLUMN "public"."matches"."group_id" IS 'FK to round_robin_groups if this match is part of RR phase';



COMMENT ON COLUMN "public"."matches"."bracket_id" IS 'FK to knockout_brackets if this match is part of KO phase';



COMMENT ON COLUMN "public"."matches"."phase" IS 'ROUND_ROBIN, KNOCKOUT, BRONZE, or FINAL';



COMMENT ON COLUMN "public"."matches"."loser_assigned_referee" IS 'User ID of loser, to be assigned as referee to next_match';



CREATE TABLE IF NOT EXISTS "public"."persons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "nickname" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "nationality_country_id" "uuid"
);


ALTER TABLE "public"."persons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."referee_volunteers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid",
    "person_id" "uuid",
    "user_id" "uuid",
    "is_active" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."referee_volunteers" OWNER TO "postgres";


COMMENT ON TABLE "public"."referee_volunteers" IS 'Tracks which players have volunteered to be referees';



COMMENT ON COLUMN "public"."referee_volunteers"."is_active" IS 'True if player is currently available to referee';



CREATE TABLE IF NOT EXISTS "public"."tournament_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category_id" "uuid",
    "display_name" "text",
    "current_handicap" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "status" "public"."entry_status" DEFAULT 'PENDING_PAYMENT'::"public"."entry_status" NOT NULL,
    "fee_amount_snap" integer,
    "checked_in_at" timestamp with time zone,
    "club_id" "uuid"
);


ALTER TABLE "public"."tournament_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tournaments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sport_id" "uuid",
    "name" "text" NOT NULL,
    "status" "public"."tournament_status" DEFAULT 'DRAFT'::"public"."tournament_status",
    "handicap_enabled" boolean DEFAULT true,
    "use_differential" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "fee_amount" integer DEFAULT 0,
    "country_id" "uuid"
);


ALTER TABLE "public"."tournaments" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."available_referees" AS
 WITH "match_players" AS (
         SELECT "m_1"."id" AS "match_id",
            "array_agg"(DISTINCT "p_1"."user_id") FILTER (WHERE ("p_1"."user_id" IS NOT NULL)) AS "playing_user_ids"
           FROM (((("public"."matches" "m_1"
             JOIN "public"."categories" "c_1" ON (("c_1"."id" = "m_1"."category_id")))
             JOIN "public"."tournament_entries" "te_1" ON (("te_1"."category_id" = "c_1"."id")))
             JOIN "public"."entry_members" "em" ON (("em"."entry_id" = "te_1"."id")))
             JOIN "public"."persons" "p_1" ON (("p_1"."id" = "em"."person_id")))
          WHERE ("te_1"."checked_in_at" IS NOT NULL)
          GROUP BY "m_1"."id"
        )
 SELECT DISTINCT ON ("mp"."match_id", "rv"."user_id") "mp"."match_id",
    "p"."user_id",
    "p"."id" AS "person_id",
    "t"."id" AS "tournament_id",
    "t"."name" AS "tournament_name",
    "c"."name" AS "category_name",
    "m"."round_name",
    COALESCE(( SELECT "count"(*) AS "count"
           FROM "public"."referee_assignments" "ra2"
          WHERE (("ra2"."user_id" = "p"."user_id") AND ("ra2"."is_confirmed" = true))), (0)::bigint) AS "matches_refereed"
   FROM ((((((("match_players" "mp"
     CROSS JOIN LATERAL "unnest"("mp"."playing_user_ids") WITH ORDINALITY "pp"("user_id", "ord"))
     JOIN "public"."matches" "m" ON (("m"."id" = "mp"."match_id")))
     JOIN "public"."categories" "c" ON (("c"."id" = "m"."category_id")))
     JOIN "public"."tournaments" "t" ON (("t"."id" = "c"."tournament_id")))
     JOIN "public"."persons" "p" ON (("p"."user_id" = "pp"."user_id")))
     JOIN "public"."tournament_entries" "te" ON ((("te"."category_id" = "c"."id") AND ("te"."checked_in_at" IS NOT NULL) AND (EXISTS ( SELECT 1
           FROM "public"."entry_members" "em2"
          WHERE (("em2"."entry_id" = "te"."id") AND ("em2"."person_id" = "p"."id")))))))
     JOIN "public"."referee_volunteers" "rv" ON ((("rv"."person_id" = "p"."id") AND ("rv"."tournament_id" = "t"."id") AND ("rv"."is_active" = true))))
  WHERE (("p"."user_id" <> ALL (COALESCE("mp"."playing_user_ids", ARRAY[]::"uuid"[]))) AND (NOT (EXISTS ( SELECT 1
           FROM "public"."referee_assignments" "ra"
          WHERE (("ra"."match_id" = "mp"."match_id") AND ("ra"."is_confirmed" = true))))))
  ORDER BY "mp"."match_id", "rv"."user_id", COALESCE(( SELECT "count"(*) AS "count"
           FROM "public"."referee_assignments" "ra2"
          WHERE (("ra2"."user_id" = "p"."user_id") AND ("ra2"."is_confirmed" = true))), (0)::bigint);


ALTER VIEW "public"."available_referees" OWNER TO "postgres";


COMMENT ON VIEW "public"."available_referees" IS 'Players available to referee a specific match. Excludes: (1) non-checked-in, (2) no user_id, (3) playing in match, (4) already assigned to another match';



CREATE TABLE IF NOT EXISTS "public"."bracket_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bracket_id" "uuid" NOT NULL,
    "position" integer NOT NULL,
    "round" integer NOT NULL,
    "round_name" "text",
    "entry_id" "uuid",
    "seed_source" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "position_positive" CHECK (("position" > 0)),
    CONSTRAINT "round_positive" CHECK (("round" > 0))
);


ALTER TABLE "public"."bracket_slots" OWNER TO "postgres";


COMMENT ON TABLE "public"."bracket_slots" IS 'Individual positions in knockout bracket';



CREATE TABLE IF NOT EXISTS "public"."club_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "club_id" "uuid" NOT NULL,
    "person_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'MEMBER'::"text",
    "joined_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "club_members_role_check" CHECK (("role" = ANY (ARRAY['OWNER'::"text", 'MEMBER'::"text"])))
);


ALTER TABLE "public"."club_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clubs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "logo_url" "text",
    "owner_user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "country_id" "uuid"
);


ALTER TABLE "public"."clubs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_feed" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid",
    "event_type" "text" NOT NULL,
    "payload_json" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."community_feed" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."countries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "iso_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "currency_code" "text",
    "flag_emoji" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."countries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."elo_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "person_id" "uuid" NOT NULL,
    "sport_id" "uuid" NOT NULL,
    "match_id" "uuid",
    "previous_elo" integer NOT NULL,
    "new_elo" integer NOT NULL,
    "elo_change" integer NOT NULL,
    "change_type" "public"."elo_change_type" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."elo_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."group_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "person_id" "uuid" NOT NULL,
    "entry_id" "uuid" NOT NULL,
    "seed" integer NOT NULL,
    "status" "public"."member_status" DEFAULT 'ACTIVE'::"public"."member_status",
    "check_in_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "round_bye" integer,
    CONSTRAINT "seed_positive" CHECK (("seed" > 0))
);


ALTER TABLE "public"."group_members" OWNER TO "postgres";


COMMENT ON TABLE "public"."group_members" IS 'Membership of players in Round Robin groups';



COMMENT ON COLUMN "public"."group_members"."seed" IS 'Seeding position (1 = head of group), unique within group';



COMMENT ON COLUMN "public"."group_members"."status" IS 'ACTIVE: playing, WALKED_OVER: did not attend, DISQUALIFIED: removed';



CREATE TABLE IF NOT EXISTS "public"."knockout_brackets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid" NOT NULL,
    "status" "public"."bracket_status" DEFAULT 'PENDING'::"public"."bracket_status",
    "third_place_enabled" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."knockout_brackets" OWNER TO "postgres";


COMMENT ON TABLE "public"."knockout_brackets" IS 'Knockout bracket generated after Round Robin completion';



CREATE TABLE IF NOT EXISTS "public"."match_sets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_id" "uuid",
    "set_number" integer NOT NULL,
    "points_a" integer DEFAULT 0,
    "points_b" integer DEFAULT 0,
    "is_finished" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."match_sets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_entry_id" "uuid",
    "user_id" "uuid",
    "provider" "text",
    "provider_txn_id" "text",
    "amount" integer NOT NULL,
    "currency" "text" DEFAULT 'USD'::"text",
    "status" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "payments_provider_check" CHECK (("provider" = ANY (ARRAY['STRIPE'::"text", 'MERCADO_PAGO'::"text"]))),
    CONSTRAINT "payments_status_check" CHECK (("status" = ANY (ARRAY['REQUIRES_PAYMENT'::"text", 'PROCESSING'::"text", 'SUCCEEDED'::"text", 'FAILED'::"text", 'REFUNDED'::"text"])))
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."player_achievements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "person_id" "uuid",
    "achievement_id" "uuid",
    "earned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."player_achievements" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."public_tournament_snapshot" AS
 SELECT "p"."id" AS "person_id",
    "p"."first_name",
    COALESCE("p"."nickname", "p"."last_name") AS "display_name",
    "ast"."current_elo",
    "ast"."sport_id"
   FROM ("public"."persons" "p"
     JOIN "public"."athlete_stats" "ast" ON (("p"."id" = "ast"."person_id")));


ALTER VIEW "public"."public_tournament_snapshot" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."round_robin_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tournament_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "advancement_count" integer DEFAULT 2,
    "status" "public"."group_status" DEFAULT 'PENDING'::"public"."group_status",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "advancement_positive" CHECK (("advancement_count" > 0)),
    CONSTRAINT "name_length" CHECK (("char_length"("name") <= 10))
);


ALTER TABLE "public"."round_robin_groups" OWNER TO "postgres";


COMMENT ON TABLE "public"."round_robin_groups" IS 'Round Robin groups for Table Tennis tournaments';



COMMENT ON COLUMN "public"."round_robin_groups"."advancement_count" IS 'How many players advance to bracket from this group';



COMMENT ON COLUMN "public"."round_robin_groups"."status" IS 'PENDING: not started, IN_PROGRESS: matches playing, COMPLETED: all matches done';



CREATE TABLE IF NOT EXISTS "public"."scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "match_id" "uuid",
    "current_set" integer DEFAULT 1,
    "points_a" integer DEFAULT 0,
    "points_b" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "local_updated_at" timestamp with time zone
);


ALTER TABLE "public"."scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "scoring_system" "public"."sport_scoring_system" NOT NULL,
    "default_points_per_set" integer DEFAULT 11,
    "default_best_of_sets" integer DEFAULT 5,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "scoring_config" "jsonb" DEFAULT '{"type": "generic", "tie_break": {"points": 7, "enabled": true}, "best_of_sets": 3, "win_condition": "points", "points_per_set": 11, "scoring_system": "standard", "match_advantages": {"enabled": false, "min_difference": 2}}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."sports" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sports"."scoring_config" IS 'JSONB containing sport-specific scoring rules:
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



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."athlete_stats"
    ADD CONSTRAINT "athlete_stats_person_id_sport_id_key" UNIQUE ("person_id", "sport_id");



ALTER TABLE ONLY "public"."athlete_stats"
    ADD CONSTRAINT "athlete_stats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bracket_slots"
    ADD CONSTRAINT "bracket_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."club_members"
    ADD CONSTRAINT "club_members_club_id_person_id_key" UNIQUE ("club_id", "person_id");



ALTER TABLE ONLY "public"."club_members"
    ADD CONSTRAINT "club_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_feed"
    ADD CONSTRAINT "community_feed_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."countries"
    ADD CONSTRAINT "countries_iso_code_key" UNIQUE ("iso_code");



ALTER TABLE ONLY "public"."countries"
    ADD CONSTRAINT "countries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."elo_history"
    ADD CONSTRAINT "elo_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entry_members"
    ADD CONSTRAINT "entry_members_entry_id_person_id_key" UNIQUE ("entry_id", "person_id");



ALTER TABLE ONLY "public"."entry_members"
    ADD CONSTRAINT "entry_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."knockout_brackets"
    ADD CONSTRAINT "knockout_brackets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."match_sets"
    ADD CONSTRAINT "match_sets_match_id_set_number_key" UNIQUE ("match_id", "set_number");



ALTER TABLE ONLY "public"."match_sets"
    ADD CONSTRAINT "match_sets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."knockout_brackets"
    ADD CONSTRAINT "one_bracket_per_tournament" UNIQUE ("tournament_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."persons"
    ADD CONSTRAINT "persons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."persons"
    ADD CONSTRAINT "persons_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."player_achievements"
    ADD CONSTRAINT "player_achievements_person_id_achievement_id_key" UNIQUE ("person_id", "achievement_id");



ALTER TABLE ONLY "public"."player_achievements"
    ADD CONSTRAINT "player_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."referee_assignments"
    ADD CONSTRAINT "referee_assignments_match_id_key" UNIQUE ("match_id");



ALTER TABLE ONLY "public"."referee_assignments"
    ADD CONSTRAINT "referee_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."referee_volunteers"
    ADD CONSTRAINT "referee_volunteers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."referee_volunteers"
    ADD CONSTRAINT "referee_volunteers_tournament_id_person_id_key" UNIQUE ("tournament_id", "person_id");



ALTER TABLE ONLY "public"."round_robin_groups"
    ADD CONSTRAINT "round_robin_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."scores"
    ADD CONSTRAINT "scores_match_id_key" UNIQUE ("match_id");



ALTER TABLE ONLY "public"."scores"
    ADD CONSTRAINT "scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sports"
    ADD CONSTRAINT "sports_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."sports"
    ADD CONSTRAINT "sports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tournament_entries"
    ADD CONSTRAINT "tournament_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tournament_staff"
    ADD CONSTRAINT "tournament_staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tournament_staff"
    ADD CONSTRAINT "tournament_staff_tournament_id_user_id_key" UNIQUE ("tournament_id", "user_id");



ALTER TABLE ONLY "public"."tournaments"
    ADD CONSTRAINT "tournaments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "unique_entry_per_group" UNIQUE ("group_id", "entry_id");



ALTER TABLE ONLY "public"."round_robin_groups"
    ADD CONSTRAINT "unique_group_name_per_tournament" UNIQUE ("tournament_id", "name");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "unique_person_per_group" UNIQUE ("group_id", "person_id");



ALTER TABLE ONLY "public"."bracket_slots"
    ADD CONSTRAINT "unique_position_per_bracket" UNIQUE ("bracket_id", "position");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "unique_seed_per_group" UNIQUE ("group_id", "seed");



CREATE INDEX "idx_bs_bracket" ON "public"."bracket_slots" USING "btree" ("bracket_id");



CREATE INDEX "idx_bs_entry" ON "public"."bracket_slots" USING "btree" ("entry_id");



CREATE INDEX "idx_bs_round" ON "public"."bracket_slots" USING "btree" ("round");



CREATE INDEX "idx_club_members_club" ON "public"."club_members" USING "btree" ("club_id");



CREATE INDEX "idx_club_members_person" ON "public"."club_members" USING "btree" ("person_id");



CREATE INDEX "idx_elo_history_match" ON "public"."elo_history" USING "btree" ("match_id");



CREATE INDEX "idx_elo_history_person_sport" ON "public"."elo_history" USING "btree" ("person_id", "sport_id");



CREATE INDEX "idx_gm_entry" ON "public"."group_members" USING "btree" ("entry_id");



CREATE INDEX "idx_gm_group" ON "public"."group_members" USING "btree" ("group_id");



CREATE INDEX "idx_gm_person" ON "public"."group_members" USING "btree" ("person_id");



CREATE INDEX "idx_gm_status" ON "public"."group_members" USING "btree" ("status");



CREATE INDEX "idx_kb_tournament" ON "public"."knockout_brackets" USING "btree" ("tournament_id");



CREATE INDEX "idx_matches_bracket" ON "public"."matches" USING "btree" ("bracket_id");



CREATE INDEX "idx_matches_group" ON "public"."matches" USING "btree" ("group_id");



CREATE INDEX "idx_matches_next" ON "public"."matches" USING "btree" ("next_match_id") WHERE ("next_match_id" IS NOT NULL);



CREATE INDEX "idx_matches_phase" ON "public"."matches" USING "btree" ("phase");



CREATE INDEX "idx_referee_assignments_match" ON "public"."referee_assignments" USING "btree" ("match_id", "is_confirmed");



CREATE INDEX "idx_referee_assignments_user" ON "public"."referee_assignments" USING "btree" ("user_id");



CREATE INDEX "idx_referee_volunteers_person" ON "public"."referee_volunteers" USING "btree" ("person_id");



CREATE INDEX "idx_referee_volunteers_tournament" ON "public"."referee_volunteers" USING "btree" ("tournament_id", "is_active");



CREATE INDEX "idx_rrg_status" ON "public"."round_robin_groups" USING "btree" ("status");



CREATE INDEX "idx_rrg_tournament" ON "public"."round_robin_groups" USING "btree" ("tournament_id");



CREATE INDEX "idx_scores_match_id" ON "public"."scores" USING "btree" ("match_id");



CREATE INDEX "idx_tournament_entries_club" ON "public"."tournament_entries" USING "btree" ("club_id");



CREATE INDEX "idx_tournament_staff_expires" ON "public"."tournament_staff" USING "btree" ("expires_at") WHERE ("expires_at" IS NOT NULL);



CREATE INDEX "idx_tournament_staff_status" ON "public"."tournament_staff" USING "btree" ("status");



CREATE INDEX "idx_tournament_staff_tournament_user" ON "public"."tournament_staff" USING "btree" ("tournament_id", "user_id");



COMMENT ON INDEX "public"."sports_pkey" IS 'Primary key index used for scoring_config lookups by sports(id)';



CREATE OR REPLACE TRIGGER "trg_advance_bracket" AFTER UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."advance_bracket_winner"();



CREATE OR REPLACE TRIGGER "trg_auto_confirm_free_entry" BEFORE INSERT ON "public"."tournament_entries" FOR EACH ROW EXECUTE FUNCTION "public"."auto_confirm_free_entry"();



CREATE OR REPLACE TRIGGER "trg_check_single_active_staff" BEFORE INSERT OR UPDATE ON "public"."tournament_staff" FOR EACH ROW EXECUTE FUNCTION "public"."check_single_active_staff"();



CREATE OR REPLACE TRIGGER "trg_feed_entry_registered" AFTER INSERT OR UPDATE ON "public"."tournament_entries" FOR EACH ROW EXECUTE FUNCTION "public"."generate_feed_event"();



CREATE OR REPLACE TRIGGER "trg_generate_match_pin" BEFORE INSERT ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."generate_match_pin"();



CREATE OR REPLACE TRIGGER "trg_kb_updated_at" BEFORE UPDATE ON "public"."knockout_brackets" FOR EACH ROW EXECUTE FUNCTION "public"."fn_update_updated_at"();



CREATE OR REPLACE TRIGGER "trg_match_completion" AFTER UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."process_match_completion"();



CREATE OR REPLACE TRIGGER "trg_matches_conflict_resolution" BEFORE UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."check_offline_sync_conflict"();



CREATE OR REPLACE TRIGGER "trg_prevent_duplicate_registration" BEFORE INSERT ON "public"."entry_members" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_duplicate_registration"();



CREATE OR REPLACE TRIGGER "trg_rrg_updated_at" BEFORE UPDATE ON "public"."round_robin_groups" FOR EACH ROW EXECUTE FUNCTION "public"."fn_update_updated_at"();



CREATE OR REPLACE TRIGGER "trg_scores_conflict_resolution" BEFORE UPDATE ON "public"."scores" FOR EACH ROW EXECUTE FUNCTION "public"."check_offline_sync_conflict"();



CREATE OR REPLACE TRIGGER "trg_tournament_created_assign_organizer" AFTER INSERT ON "public"."tournaments" FOR EACH ROW EXECUTE FUNCTION "public"."assign_tournament_creator_as_organizer"();



CREATE OR REPLACE TRIGGER "trg_track_loser_for_referee" AFTER UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."fn_track_loser_for_referee"();



CREATE OR REPLACE TRIGGER "trg_unique_person_per_tournament" BEFORE INSERT ON "public"."group_members" FOR EACH ROW EXECUTE FUNCTION "public"."fn_unique_person_per_tournament"();



CREATE OR REPLACE TRIGGER "trg_unique_seed_per_group" BEFORE INSERT OR UPDATE ON "public"."group_members" FOR EACH ROW EXECUTE FUNCTION "public"."fn_unique_seed_per_group"();



CREATE OR REPLACE TRIGGER "trg_update_athlete_rank" BEFORE INSERT OR UPDATE OF "current_elo" ON "public"."athlete_stats" FOR EACH ROW EXECUTE FUNCTION "public"."update_athlete_rank"();



CREATE OR REPLACE TRIGGER "trg_update_group_status" AFTER UPDATE ON "public"."matches" FOR EACH ROW EXECUTE FUNCTION "public"."fn_update_group_status_on_match_complete"();



CREATE OR REPLACE TRIGGER "trg_update_referee_stats" AFTER UPDATE ON "public"."referee_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_referee_stats"();



CREATE OR REPLACE TRIGGER "trg_validate_attendance_change" BEFORE UPDATE ON "public"."tournament_entries" FOR EACH ROW EXECUTE FUNCTION "public"."validate_attendance_change"();



CREATE OR REPLACE TRIGGER "trg_validate_category_delete" BEFORE DELETE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."validate_category_delete"();



CREATE OR REPLACE TRIGGER "trg_validate_group_member_count" BEFORE INSERT ON "public"."group_members" FOR EACH ROW EXECUTE FUNCTION "public"."fn_validate_group_member_count"();



CREATE OR REPLACE TRIGGER "trg_validate_referee_assignment" BEFORE INSERT OR UPDATE ON "public"."referee_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."fn_validate_referee_assignment"();



CREATE OR REPLACE TRIGGER "trg_validate_score" BEFORE INSERT OR UPDATE ON "public"."scores" FOR EACH ROW EXECUTE FUNCTION "public"."trg_validate_score"();



COMMENT ON TRIGGER "trg_validate_score" ON "public"."scores" IS 'BEFORE INSERT/UPDATE trigger that validates score values against sport scoring rules.
Rejects invalid scores (e.g., 11-10 without golden point, scores below winning threshold).';



ALTER TABLE ONLY "public"."athlete_stats"
    ADD CONSTRAINT "athlete_stats_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."athlete_stats"
    ADD CONSTRAINT "athlete_stats_sport_id_fkey" FOREIGN KEY ("sport_id") REFERENCES "public"."sports"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bracket_slots"
    ADD CONSTRAINT "bracket_slots_bracket_id_fkey" FOREIGN KEY ("bracket_id") REFERENCES "public"."knockout_brackets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bracket_slots"
    ADD CONSTRAINT "bracket_slots_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "public"."tournament_entries"("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "public"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."club_members"
    ADD CONSTRAINT "club_members_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."club_members"
    ADD CONSTRAINT "club_members_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "public"."countries"("id");



ALTER TABLE ONLY "public"."clubs"
    ADD CONSTRAINT "clubs_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_feed"
    ADD CONSTRAINT "community_feed_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "public"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."elo_history"
    ADD CONSTRAINT "elo_history_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."elo_history"
    ADD CONSTRAINT "elo_history_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."elo_history"
    ADD CONSTRAINT "elo_history_sport_id_fkey" FOREIGN KEY ("sport_id") REFERENCES "public"."sports"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entry_members"
    ADD CONSTRAINT "entry_members_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "public"."tournament_entries"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entry_members"
    ADD CONSTRAINT "entry_members_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "public"."tournament_entries"("id");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."round_robin_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id");



ALTER TABLE ONLY "public"."knockout_brackets"
    ADD CONSTRAINT "knockout_brackets_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "public"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_sets"
    ADD CONSTRAINT "match_sets_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_bracket_id_fkey" FOREIGN KEY ("bracket_id") REFERENCES "public"."knockout_brackets"("id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_entry_a_id_fkey" FOREIGN KEY ("entry_a_id") REFERENCES "public"."tournament_entries"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_entry_b_id_fkey" FOREIGN KEY ("entry_b_id") REFERENCES "public"."tournament_entries"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."round_robin_groups"("id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_loser_assigned_referee_fkey" FOREIGN KEY ("loser_assigned_referee") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_next_match_id_fkey" FOREIGN KEY ("next_match_id") REFERENCES "public"."matches"("id") DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."matches"
    ADD CONSTRAINT "matches_referee_id_fkey" FOREIGN KEY ("referee_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_tournament_entry_id_fkey" FOREIGN KEY ("tournament_entry_id") REFERENCES "public"."tournament_entries"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."persons"
    ADD CONSTRAINT "persons_nationality_country_id_fkey" FOREIGN KEY ("nationality_country_id") REFERENCES "public"."countries"("id");



ALTER TABLE ONLY "public"."persons"
    ADD CONSTRAINT "persons_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."player_achievements"
    ADD CONSTRAINT "player_achievements_achievement_id_fkey" FOREIGN KEY ("achievement_id") REFERENCES "public"."achievements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_achievements"
    ADD CONSTRAINT "player_achievements_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."referee_assignments"
    ADD CONSTRAINT "referee_assignments_assigned_by_fkey" FOREIGN KEY ("assigned_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."referee_assignments"
    ADD CONSTRAINT "referee_assignments_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."referee_assignments"
    ADD CONSTRAINT "referee_assignments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."referee_volunteers"
    ADD CONSTRAINT "referee_volunteers_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."persons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."referee_volunteers"
    ADD CONSTRAINT "referee_volunteers_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "public"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."referee_volunteers"
    ADD CONSTRAINT "referee_volunteers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."round_robin_groups"
    ADD CONSTRAINT "round_robin_groups_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "public"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."scores"
    ADD CONSTRAINT "scores_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "public"."matches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tournament_entries"
    ADD CONSTRAINT "tournament_entries_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tournament_entries"
    ADD CONSTRAINT "tournament_entries_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "public"."clubs"("id");



ALTER TABLE ONLY "public"."tournament_staff"
    ADD CONSTRAINT "tournament_staff_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tournament_staff"
    ADD CONSTRAINT "tournament_staff_tournament_id_fkey" FOREIGN KEY ("tournament_id") REFERENCES "public"."tournaments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tournament_staff"
    ADD CONSTRAINT "tournament_staff_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tournaments"
    ADD CONSTRAINT "tournaments_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "public"."countries"("id");



ALTER TABLE ONLY "public"."tournaments"
    ADD CONSTRAINT "tournaments_sport_id_fkey" FOREIGN KEY ("sport_id") REFERENCES "public"."sports"("id") ON DELETE RESTRICT;



CREATE POLICY "Admins can delete sports" ON "public"."sports" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Admins can insert sports" ON "public"."sports" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Admins can update sports" ON "public"."sports" FOR UPDATE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Anyone can view referee volunteers" ON "public"."referee_volunteers" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authenticated users can view categories" ON "public"."categories" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view clubs" ON "public"."clubs" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view entries" ON "public"."tournament_entries" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view entry members" ON "public"."entry_members" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view feed" ON "public"."community_feed" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view matches" ON "public"."matches" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authenticated users can view scores" ON "public"."scores" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authenticated users can view sports" ON "public"."sports" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



COMMENT ON POLICY "Authenticated users can view sports" ON "public"."sports" IS 'All authenticated users can view sports including scoring_config for tournament setup';



CREATE POLICY "Club members can view their clubs" ON "public"."club_members" FOR SELECT USING ((("auth"."uid"() IN ( SELECT "c"."owner_user_id"
   FROM "public"."clubs" "c"
  WHERE ("c"."id" = "club_members"."club_id"))) OR ("auth"."uid"() IN ( SELECT "p"."user_id"
   FROM "public"."persons" "p"
  WHERE ("p"."id" = "club_members"."person_id")))));



CREATE POLICY "Club owners can add members" ON "public"."club_members" FOR INSERT WITH CHECK (("auth"."uid"() IN ( SELECT "c"."owner_user_id"
   FROM "public"."clubs" "c"
  WHERE ("c"."id" = "club_members"."club_id"))));



CREATE POLICY "Club owners can delete clubs" ON "public"."clubs" FOR DELETE USING (("auth"."uid"() = "owner_user_id"));



CREATE POLICY "Club owners can update clubs" ON "public"."clubs" FOR UPDATE USING (("auth"."uid"() = "owner_user_id"));



CREATE POLICY "Club owners or members can remove themselves" ON "public"."club_members" FOR DELETE USING ((("auth"."uid"() IN ( SELECT "c"."owner_user_id"
   FROM "public"."clubs" "c"
  WHERE ("c"."id" = "club_members"."club_id"))) OR ("auth"."uid"() IN ( SELECT "p"."user_id"
   FROM "public"."persons" "p"
  WHERE ("p"."id" = "club_members"."person_id")))));



CREATE POLICY "Elo history is read only for users" ON "public"."elo_history" FOR SELECT USING (true);



CREATE POLICY "Entry owner or organizer can update entries" ON "public"."tournament_entries" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM (("public"."tournament_staff" "ts"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "ts"."tournament_id")))
     JOIN "public"."tournament_entries" "te" ON (("te"."category_id" = "c"."id")))
  WHERE (("te"."id" = "tournament_entries"."id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text")))) OR (EXISTS ( SELECT 1
   FROM ("public"."entry_members" "em"
     JOIN "public"."persons" "p" ON (("p"."id" = "em"."person_id")))
  WHERE (("em"."entry_id" = "tournament_entries"."id") AND ("p"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Entry owner or organizer can update status" ON "public"."tournament_entries" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM ("public"."entry_members" "em"
     JOIN "public"."persons" "p" ON (("em"."person_id" = "p"."id")))
  WHERE (("em"."entry_id" = "tournament_entries"."id") AND ("p"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM ("public"."categories" "c"
     JOIN "public"."tournament_staff" "ts" ON (("c"."tournament_id" = "ts"."tournament_id")))
  WHERE (("c"."id" = "tournament_entries"."category_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text"))))));



CREATE POLICY "Matches refer to authorized staff" ON "public"."matches" USING ((EXISTS ( SELECT 1
   FROM ("public"."categories" "c"
     JOIN "public"."tournament_staff" "ts" ON (("c"."tournament_id" = "ts"."tournament_id")))
  WHERE (("c"."id" = "matches"."category_id") AND ("ts"."user_id" = "matches"."referee_id")))));



CREATE POLICY "Only via trigger can insert scores" ON "public"."scores" FOR INSERT WITH CHECK (false);



CREATE POLICY "Organizer can update third place flags" ON "public"."matches" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "ts"."tournament_id")))
  WHERE (("c"."id" = "matches"."category_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text")))));



CREATE POLICY "Organizers and referees can view assignments" ON "public"."referee_assignments" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."matches" "m" ON (("m"."category_id" IN ( SELECT "categories"."id"
           FROM "public"."categories"
          WHERE ("categories"."tournament_id" = "ts"."tournament_id")))))
  WHERE (("m"."id" = "referee_assignments"."match_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))) OR ("user_id" = "auth"."uid"())));



CREATE POLICY "Organizers can create assignments" ON "public"."referee_assignments" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."matches" "m" ON (("m"."category_id" IN ( SELECT "categories"."id"
           FROM "public"."categories"
          WHERE ("categories"."tournament_id" = "ts"."tournament_id")))))
  WHERE (("m"."id" = "referee_assignments"."match_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))) OR ("user_id" = "auth"."uid"())));



CREATE POLICY "Organizers can create categories" ON "public"."categories" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "categories"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text")))));



CREATE POLICY "Organizers can create matches" ON "public"."matches" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "ts"."tournament_id")))
  WHERE (("c"."id" = "matches"."category_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))));



CREATE POLICY "Organizers can delete empty categories" ON "public"."categories" FOR DELETE USING (((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."tournaments" "t" ON (("t"."id" = "ts"."tournament_id")))
  WHERE (("ts"."tournament_id" = "categories"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("t"."status" <> ALL (ARRAY['LIVE'::"public"."tournament_status", 'COMPLETED'::"public"."tournament_status"]))))) AND (NOT (EXISTS ( SELECT 1
   FROM "public"."tournament_entries" "te"
  WHERE ("te"."category_id" = "categories"."id"))))));



CREATE POLICY "Organizers can delete feed entries" ON "public"."community_feed" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "community_feed"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text")))));



CREATE POLICY "Organizers can delete staff" ON "public"."tournament_staff" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "tournament_staff"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))));



CREATE POLICY "Organizers can delete tournaments" ON "public"."tournaments" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "tournaments"."id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))));



CREATE POLICY "Organizers can insert staff" ON "public"."tournament_staff" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "tournament_staff"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))));



CREATE POLICY "Organizers can modify assignments" ON "public"."referee_assignments" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."matches" "m" ON (("m"."category_id" IN ( SELECT "categories"."id"
           FROM "public"."categories"
          WHERE ("categories"."tournament_id" = "ts"."tournament_id")))))
  WHERE (("m"."id" = "referee_assignments"."match_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))));



CREATE POLICY "Organizers can update all staff" ON "public"."tournament_staff" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "tournament_staff"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))) OR ("user_id" = "auth"."uid"())));



CREATE POLICY "Organizers can update categories" ON "public"."categories" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."tournaments" "t" ON (("t"."id" = "ts"."tournament_id")))
  WHERE (("ts"."tournament_id" = "categories"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("t"."status" <> ALL (ARRAY['LIVE'::"public"."tournament_status", 'COMPLETED'::"public"."tournament_status"]))))));



CREATE POLICY "Organizers can update matches" ON "public"."matches" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM ("public"."tournament_staff" "ts"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "ts"."tournament_id")))
  WHERE (("c"."id" = "matches"."category_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))) OR ("referee_id" = "auth"."uid"())));



CREATE POLICY "Organizers can update tournaments" ON "public"."tournaments" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "tournaments"."id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status")))));



CREATE POLICY "Organizers can view all staff" ON "public"."tournament_staff" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts2"
  WHERE (("ts2"."tournament_id" = "tournament_staff"."tournament_id") AND ("ts2"."user_id" = "auth"."uid"()) AND ("ts2"."role" = 'ORGANIZER'::"text") AND ("ts2"."status" = 'ACTIVE'::"public"."staff_status")))) OR ("user_id" = "auth"."uid"())));



CREATE POLICY "Persons are readable by authenticated users" ON "public"."persons" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Players can read third place flags" ON "public"."matches" FOR SELECT USING ((("entry_a_id" IN ( SELECT "em"."entry_id"
   FROM ("public"."entry_members" "em"
     JOIN "public"."persons" "p" ON (("em"."person_id" = "p"."id")))
  WHERE ("p"."user_id" = "auth"."uid"()))) OR ("entry_b_id" IN ( SELECT "em"."entry_id"
   FROM ("public"."entry_members" "em"
     JOIN "public"."persons" "p" ON (("em"."person_id" = "p"."id")))
  WHERE ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "Referee or organizer can update scores" ON "public"."scores" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."matches" "m"
  WHERE (("m"."id" = "scores"."match_id") AND ("m"."referee_id" = "auth"."uid"()) AND ("m"."status" = 'LIVE'::"public"."match_status")))) OR (EXISTS ( SELECT 1
   FROM (("public"."tournament_staff" "ts"
     JOIN "public"."matches" "m" ON (("m"."category_id" IN ( SELECT "categories"."id"
           FROM "public"."categories"
          WHERE ("categories"."tournament_id" = "ts"."tournament_id")))))
     JOIN "public"."scores" "s" ON (("s"."match_id" = "m"."id")))
  WHERE (("m"."id" = "scores"."match_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status"))))));



CREATE POLICY "Staff can create feed entries" ON "public"."community_feed" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "community_feed"."tournament_id") AND ("ts"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can add themselves to entries" ON "public"."entry_members" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Users can cancel own entries" ON "public"."tournament_entries" FOR DELETE USING (((NOT (EXISTS ( SELECT 1
   FROM (("public"."tournaments" "t"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "t"."id")))
     JOIN "public"."tournament_entries" "te" ON (("te"."category_id" = "c"."id")))
  WHERE (("te"."id" = "tournament_entries"."id") AND ("t"."status" = ANY (ARRAY['LIVE'::"public"."tournament_status", 'COMPLETED'::"public"."tournament_status"])))))) AND ((EXISTS ( SELECT 1
   FROM (("public"."tournament_staff" "ts"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "ts"."tournament_id")))
     JOIN "public"."tournament_entries" "te" ON (("te"."category_id" = "c"."id")))
  WHERE (("te"."id" = "tournament_entries"."id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text")))) OR (EXISTS ( SELECT 1
   FROM ("public"."entry_members" "em"
     JOIN "public"."persons" "p" ON (("p"."id" = "em"."person_id")))
  WHERE (("em"."entry_id" = "tournament_entries"."id") AND ("p"."user_id" = "auth"."uid"())))))));



CREATE POLICY "Users can create clubs" ON "public"."clubs" FOR INSERT WITH CHECK (("auth"."uid"() = "owner_user_id"));



CREATE POLICY "Users can create entries during registration" ON "public"."tournament_entries" FOR INSERT WITH CHECK ((("auth"."role"() = 'authenticated'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."tournaments" "t"
     JOIN "public"."categories" "c" ON (("c"."tournament_id" = "t"."id")))
  WHERE (("c"."id" = "tournament_entries"."category_id") AND ("t"."status" = 'REGISTRATION'::"public"."tournament_status"))))));



CREATE POLICY "Users can create own person or guest" ON "public"."persons" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR ("user_id" IS NULL)));



CREATE POLICY "Users can create tournaments" ON "public"."tournaments" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can delete own person" ON "public"."persons" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage own volunteer status" ON "public"."referee_volunteers" USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."tournament_staff" "ts"
  WHERE (("ts"."tournament_id" = "referee_volunteers"."tournament_id") AND ("ts"."user_id" = "auth"."uid"()) AND ("ts"."role" = 'ORGANIZER'::"text") AND ("ts"."status" = 'ACTIVE'::"public"."staff_status"))))));



CREATE POLICY "Users can remove themselves from entries" ON "public"."entry_members" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."persons" "p"
  WHERE (("p"."id" = "entry_members"."person_id") AND ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can update own person" ON "public"."persons" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."club_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clubs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_feed" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."elo_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."entry_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."matches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."persons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tournament_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tournament_staff" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tournaments" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";





GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";































































































































































GRANT ALL ON TABLE "public"."tournament_staff" TO "anon";
GRANT ALL ON TABLE "public"."tournament_staff" TO "authenticated";
GRANT ALL ON TABLE "public"."tournament_staff" TO "service_role";



GRANT ALL ON FUNCTION "public"."accept_invitation"("p_tournament_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_invitation"("p_tournament_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_invitation"("p_tournament_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."accept_third_place"("p_match_id" "uuid", "p_accepted" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."accept_third_place"("p_match_id" "uuid", "p_accepted" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_third_place"("p_match_id" "uuid", "p_accepted" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_member_to_group"("p_group_id" "uuid", "p_entry_id" "uuid", "p_seed" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_member_to_group"("p_group_id" "uuid", "p_entry_id" "uuid", "p_seed" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_member_to_group"("p_group_id" "uuid", "p_entry_id" "uuid", "p_seed" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."advance_bracket_winner"() TO "anon";
GRANT ALL ON FUNCTION "public"."advance_bracket_winner"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."advance_bracket_winner"() TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_loser_as_referee"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."assign_loser_as_referee"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_loser_as_referee"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_invite_mode" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."assign_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_invite_mode" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text", "p_invite_mode" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."assign_tournament_creator_as_organizer"() TO "anon";
GRANT ALL ON FUNCTION "public"."assign_tournament_creator_as_organizer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_tournament_creator_as_organizer"() TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_confirm_free_entry"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_confirm_free_entry"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_confirm_free_entry"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_game_winner"("p_score_a" integer, "p_score_b" integer, "p_scoring_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_game_winner"("p_score_a" integer, "p_score_b" integer, "p_scoring_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_game_winner"("p_score_a" integer, "p_score_b" integer, "p_scoring_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_group_standings"("p_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_group_standings"("p_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_group_standings"("p_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_set_winner"("p_sets" "jsonb", "p_scoring_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_set_winner"("p_sets" "jsonb", "p_scoring_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_set_winner"("p_sets" "jsonb", "p_scoring_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_offline_sync_conflict"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_offline_sync_conflict"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_offline_sync_conflict"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_single_active_staff"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_single_active_staff"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_single_active_staff"() TO "service_role";



GRANT ALL ON FUNCTION "public"."clear_match_referee"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."clear_match_referee"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_match_referee"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."referee_assignments" TO "anon";
GRANT ALL ON TABLE "public"."referee_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."referee_assignments" TO "service_role";



GRANT ALL ON FUNCTION "public"."confirm_referee_assignment"("p_match_id" "uuid", "p_user_id" "uuid", "p_is_organizer_override" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."confirm_referee_assignment"("p_match_id" "uuid", "p_user_id" "uuid", "p_is_organizer_override" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."confirm_referee_assignment"("p_match_id" "uuid", "p_user_id" "uuid", "p_is_organizer_override" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_round_robin_group"("p_tournament_id" "uuid", "p_name" "text", "p_member_entry_ids" "uuid"[], "p_advancement_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_round_robin_group"("p_tournament_id" "uuid", "p_name" "text", "p_member_entry_ids" "uuid"[], "p_advancement_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_round_robin_group"("p_tournament_id" "uuid", "p_name" "text", "p_member_entry_ids" "uuid"[], "p_advancement_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_third_place_match"("p_semi_a" "uuid", "p_semi_b" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_third_place_match"("p_semi_a" "uuid", "p_semi_b" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_third_place_match"("p_semi_a" "uuid", "p_semi_b" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_track_loser_for_referee"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_track_loser_for_referee"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_track_loser_for_referee"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_unique_person_per_tournament"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_unique_person_per_tournament"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_unique_person_per_tournament"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_unique_seed_per_group"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_unique_seed_per_group"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_unique_seed_per_group"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_update_group_status_on_match_complete"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_update_group_status_on_match_complete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_update_group_status_on_match_complete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_update_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_update_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_update_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_validate_group_member_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_validate_group_member_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_validate_group_member_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_validate_referee_assignment"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_validate_referee_assignment"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_validate_referee_assignment"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bracket"("p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bracket"("p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bracket"("p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_bracket_from_groups"("p_tournament_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_bracket_from_groups"("p_tournament_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_bracket_from_groups"("p_tournament_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_feed_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_feed_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_feed_event"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_match_pin"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_match_pin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_match_pin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_referee_suggestions"("p_category_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_referee_suggestions"("p_category_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_referee_suggestions"("p_category_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_round_robin_matches"("p_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_round_robin_matches"("p_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_round_robin_matches"("p_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_available_referees"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_available_referees"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_available_referees"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_match_loser"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_match_loser"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_match_loser"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."inherit_tournament_country"() TO "anon";
GRANT ALL ON FUNCTION "public"."inherit_tournament_country"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."inherit_tournament_country"() TO "service_role";



GRANT ALL ON FUNCTION "public"."invite_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."invite_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."invite_staff"("p_tournament_id" "uuid", "p_user_id" "uuid", "p_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_tiebreak"("p_game_a" integer, "p_game_b" integer, "p_scoring_config" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."is_tiebreak"("p_game_a" integer, "p_game_b" integer, "p_scoring_config" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_tiebreak"("p_game_a" integer, "p_game_b" integer, "p_scoring_config" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."manage_sports"() TO "anon";
GRANT ALL ON FUNCTION "public"."manage_sports"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."manage_sports"() TO "service_role";



GRANT ALL ON FUNCTION "public"."offer_third_place"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."offer_third_place"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."offer_third_place"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_duplicate_registration"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_duplicate_registration"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_duplicate_registration"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_match_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_match_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_match_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."reject_invitation"("p_tournament_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reject_invitation"("p_tournament_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reject_invitation"("p_tournament_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."revoke_staff"("p_tournament_id" "uuid", "p_target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."revoke_staff"("p_tournament_id" "uuid", "p_target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."revoke_staff"("p_tournament_id" "uuid", "p_target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rollback_match"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."rollback_match"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rollback_match"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."suggest_intra_group_referee"("p_match_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."suggest_intra_group_referee"("p_match_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."suggest_intra_group_referee"("p_match_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_referee_volunteer"("p_tournament_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_referee_volunteer"("p_tournament_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_referee_volunteer"("p_tournament_id" "uuid", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."trg_validate_score"() TO "anon";
GRANT ALL ON FUNCTION "public"."trg_validate_score"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trg_validate_score"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_athlete_rank"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_athlete_rank"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_athlete_rank"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_referee_stats"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_referee_stats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_referee_stats"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_attendance_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_attendance_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_attendance_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_category_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_category_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_category_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_match_entry"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_match_entry"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_match_entry"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_score"("p_match_id" "uuid", "p_points_a" integer, "p_points_b" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."validate_score"("p_match_id" "uuid", "p_points_a" integer, "p_points_b" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_score"("p_match_id" "uuid", "p_points_a" integer, "p_points_b" integer) TO "service_role";


















GRANT ALL ON TABLE "public"."achievements" TO "anon";
GRANT ALL ON TABLE "public"."achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."achievements" TO "service_role";



GRANT ALL ON TABLE "public"."athlete_stats" TO "anon";
GRANT ALL ON TABLE "public"."athlete_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."athlete_stats" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."entry_members" TO "anon";
GRANT ALL ON TABLE "public"."entry_members" TO "authenticated";
GRANT ALL ON TABLE "public"."entry_members" TO "service_role";



GRANT ALL ON TABLE "public"."matches" TO "anon";
GRANT ALL ON TABLE "public"."matches" TO "authenticated";
GRANT ALL ON TABLE "public"."matches" TO "service_role";



GRANT ALL ON TABLE "public"."persons" TO "anon";
GRANT ALL ON TABLE "public"."persons" TO "authenticated";
GRANT ALL ON TABLE "public"."persons" TO "service_role";



GRANT ALL ON TABLE "public"."referee_volunteers" TO "anon";
GRANT ALL ON TABLE "public"."referee_volunteers" TO "authenticated";
GRANT ALL ON TABLE "public"."referee_volunteers" TO "service_role";



GRANT ALL ON TABLE "public"."tournament_entries" TO "anon";
GRANT ALL ON TABLE "public"."tournament_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."tournament_entries" TO "service_role";



GRANT ALL ON TABLE "public"."tournaments" TO "anon";
GRANT ALL ON TABLE "public"."tournaments" TO "authenticated";
GRANT ALL ON TABLE "public"."tournaments" TO "service_role";



GRANT ALL ON TABLE "public"."available_referees" TO "anon";
GRANT ALL ON TABLE "public"."available_referees" TO "authenticated";
GRANT ALL ON TABLE "public"."available_referees" TO "service_role";



GRANT ALL ON TABLE "public"."bracket_slots" TO "anon";
GRANT ALL ON TABLE "public"."bracket_slots" TO "authenticated";
GRANT ALL ON TABLE "public"."bracket_slots" TO "service_role";



GRANT ALL ON TABLE "public"."club_members" TO "anon";
GRANT ALL ON TABLE "public"."club_members" TO "authenticated";
GRANT ALL ON TABLE "public"."club_members" TO "service_role";



GRANT ALL ON TABLE "public"."clubs" TO "anon";
GRANT ALL ON TABLE "public"."clubs" TO "authenticated";
GRANT ALL ON TABLE "public"."clubs" TO "service_role";



GRANT ALL ON TABLE "public"."community_feed" TO "anon";
GRANT ALL ON TABLE "public"."community_feed" TO "authenticated";
GRANT ALL ON TABLE "public"."community_feed" TO "service_role";



GRANT ALL ON TABLE "public"."countries" TO "anon";
GRANT ALL ON TABLE "public"."countries" TO "authenticated";
GRANT ALL ON TABLE "public"."countries" TO "service_role";



GRANT ALL ON TABLE "public"."elo_history" TO "anon";
GRANT ALL ON TABLE "public"."elo_history" TO "authenticated";
GRANT ALL ON TABLE "public"."elo_history" TO "service_role";



GRANT ALL ON TABLE "public"."group_members" TO "anon";
GRANT ALL ON TABLE "public"."group_members" TO "authenticated";
GRANT ALL ON TABLE "public"."group_members" TO "service_role";



GRANT ALL ON TABLE "public"."knockout_brackets" TO "anon";
GRANT ALL ON TABLE "public"."knockout_brackets" TO "authenticated";
GRANT ALL ON TABLE "public"."knockout_brackets" TO "service_role";



GRANT ALL ON TABLE "public"."match_sets" TO "anon";
GRANT ALL ON TABLE "public"."match_sets" TO "authenticated";
GRANT ALL ON TABLE "public"."match_sets" TO "service_role";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON TABLE "public"."player_achievements" TO "anon";
GRANT ALL ON TABLE "public"."player_achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."player_achievements" TO "service_role";



GRANT ALL ON TABLE "public"."public_tournament_snapshot" TO "anon";
GRANT ALL ON TABLE "public"."public_tournament_snapshot" TO "authenticated";
GRANT ALL ON TABLE "public"."public_tournament_snapshot" TO "service_role";



GRANT ALL ON TABLE "public"."round_robin_groups" TO "anon";
GRANT ALL ON TABLE "public"."round_robin_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."round_robin_groups" TO "service_role";



GRANT ALL ON TABLE "public"."scores" TO "anon";
GRANT ALL ON TABLE "public"."scores" TO "authenticated";
GRANT ALL ON TABLE "public"."scores" TO "service_role";



GRANT ALL ON TABLE "public"."sports" TO "anon";
GRANT ALL ON TABLE "public"."sports" TO "authenticated";
GRANT ALL ON TABLE "public"."sports" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































