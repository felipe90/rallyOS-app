-- ============================================================
-- Migration: 00000000000029_staff_rls_update
-- Purpose:
--   Update RLS policies for staff management and player-as-referee
-- ============================================================

BEGIN;

-- =============================================================================
-- 1. TOURNAMENT_STAFF RLS
-- =============================================================================

-- Drop old policy that was too restrictive
DROP POLICY IF EXISTS "Only organizers can manage staff" ON tournament_staff;

-- SELECT: Organizers see all, users see their own
CREATE POLICY "Organizers can view all staff" ON tournament_staff
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts2
        WHERE ts2.tournament_id = tournament_staff.tournament_id
          AND ts2.user_id = auth.uid()
          AND ts2.role = 'ORGANIZER'
          AND ts2.status = 'ACTIVE'
    )
    OR tournament_staff.user_id = auth.uid()
);

-- INSERT: Organizers only
CREATE POLICY "Organizers can insert staff" ON tournament_staff
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = tournament_staff.tournament_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- UPDATE: Organizers can update, users can update their own status (for accept/reject)
CREATE POLICY "Organizers can update all staff" ON tournament_staff
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = tournament_staff.tournament_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
    OR tournament_staff.user_id = auth.uid()  -- Users can update their own (accept/reject)
);

-- DELETE: Organizers only
CREATE POLICY "Organizers can delete staff" ON tournament_staff
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = tournament_staff.tournament_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- =============================================================================
-- 2. MATCHES RLS
-- =============================================================================

-- SELECT: Anyone authenticated can view matches
CREATE POLICY "Authenticated users can view matches" ON matches
FOR SELECT USING (auth.uid() IS NOT NULL);

-- For UPDATE (including referee_id assignment):
-- Only organizers can update match metadata
-- Only assigned referees can update scores (handled in scores policy)
CREATE POLICY "Organizers can update matches" ON matches
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = matches.category_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
    OR matches.referee_id = auth.uid()  -- Referees can update their assigned matches
);

-- INSERT: Only via RPC (generate_bracket), not direct
CREATE POLICY "Organizers can create matches" ON matches
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = matches.category_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- =============================================================================
-- 3. SCORES RLS
-- =============================================================================

-- Drop old restrictive policy
DROP POLICY IF EXISTS "Scores insert/update allowed only for assigned referee" ON scores;

-- SELECT: Anyone authenticated can view scores
CREATE POLICY "Authenticated users can view scores" ON scores
FOR SELECT USING (auth.uid() IS NOT NULL);

-- UPDATE: Only assigned referee or organizer
CREATE POLICY "Referee or organizer can update scores" ON scores
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM matches m
        WHERE m.id = scores.match_id
          AND m.referee_id = auth.uid()
          AND m.status = 'LIVE'
    )
    OR EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN matches m ON m.category_id IN (SELECT id FROM categories WHERE tournament_id = ts.tournament_id)
        JOIN scores s ON s.match_id = m.id
        WHERE m.id = scores.match_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- INSERT: Only via RPC, not direct
CREATE POLICY "Only via trigger can insert scores" ON scores
FOR INSERT WITH CHECK (false);  -- Deny direct inserts

-- =============================================================================
-- 4. REFEREE_VOLUNTEERS RLS
-- =============================================================================

-- SELECT: Anyone can view (for displaying availability)
CREATE POLICY "Anyone can view referee volunteers" ON referee_volunteers
FOR SELECT USING (auth.uid() IS NOT NULL);

-- INSERT/UPDATE/DELETE: Only the person themselves or organizer
CREATE POLICY "Users can manage own volunteer status" ON referee_volunteers
FOR ALL USING (
    referee_volunteers.user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = referee_volunteers.tournament_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- =============================================================================
-- 5. REFEREE_ASSIGNMENTS RLS
-- =============================================================================

-- SELECT: Organizers see all, referees see their assignments
CREATE POLICY "Organizers and referees can view assignments" ON referee_assignments
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN matches m ON m.category_id IN (SELECT id FROM categories WHERE tournament_id = ts.tournament_id)
        WHERE m.id = referee_assignments.match_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
    OR referee_assignments.user_id = auth.uid()
);

-- INSERT: Organizers or system (via RPC)
CREATE POLICY "Organizers can create assignments" ON referee_assignments
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN matches m ON m.category_id IN (SELECT id FROM categories WHERE tournament_id = ts.tournament_id)
        WHERE m.id = referee_assignments.match_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
    OR referee_assignments.user_id = auth.uid()  -- Users can confirm their own suggestions
);

-- UPDATE: Organizers can modify, referees can confirm their suggestions
CREATE POLICY "Organizers can modify assignments" ON referee_assignments
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN matches m ON m.category_id IN (SELECT id FROM categories WHERE tournament_id = ts.tournament_id)
        WHERE m.id = referee_assignments.match_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- =============================================================================
-- 6. AVAILABLE_REFEREES VIEW RLS
-- =============================================================================

-- Create policy for the view - anyone authenticated can query
-- The view itself filters based on checked_in, volunteer status, etc.

-- =============================================================================
-- 7. TOURNAMENTS RLS (update for organizer-only modifications)
-- =============================================================================

-- Keep existing policies but add organizer check for UPDATE/DELETE
-- (SELECT should remain public for listing)

-- Existing policies should still work, but let's ensure organizers can modify
CREATE POLICY "Organizers can update tournaments" ON tournaments
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = tournaments.id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

-- Ensure status transitions are only by organizers
CREATE POLICY "Organizers can delete tournaments" ON tournaments
FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = tournaments.id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);

COMMIT;
