-- Migration: 00000000000048_rls_sensitive_tables.sql
-- Purpose: RLS policies for sensitive tables (athlete_stats, payments, match_sets)

-- Enable RLS on all target tables
ALTER TABLE athlete_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_sets ENABLE ROW LEVEL SECURITY;

-- ============================================
-- athlete_stats policies
-- ============================================

-- Drop existing policies if they exist (idempotent)
DROP POLICY IF EXISTS "Authenticated users can view athlete stats" ON athlete_stats;
DROP POLICY IF EXISTS "Players can update own stats" ON athlete_stats;

-- SELECT: Any authenticated user can view stats (for public profiles)
CREATE POLICY "Authenticated users can view athlete stats"
ON athlete_stats FOR SELECT TO authenticated
USING (TRUE);

-- UPDATE: Only own record (via persons.user_id link)
CREATE POLICY "Players can update own stats"
ON athlete_stats FOR UPDATE TO authenticated
USING (
    person_id IN (
        SELECT id FROM persons WHERE user_id = auth.uid()
    )
);

-- INSERT/DELETE: Blocked implicitly by not creating policies

-- ============================================
-- payments policies
-- ============================================

-- Drop existing policies if they exist (idempotent)
DROP POLICY IF EXISTS "Users can view own payments" ON payments;
DROP POLICY IF EXISTS "Payments insert blocked for users" ON payments;
DROP POLICY IF EXISTS "Organizers can update payment status" ON payments;

-- SELECT: Own payments OR tournament organizer
CREATE POLICY "Users can view own payments"
ON payments FOR SELECT TO authenticated
USING (
    user_id = auth.uid()
    OR
    tournament_entry_id IN (
        SELECT te.id FROM tournament_entries te
        JOIN categories c ON c.id = te.category_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);

-- INSERT: Blocked for users (only payment processor can insert)
CREATE POLICY "Payments insert blocked for users"
ON payments FOR INSERT TO authenticated WITH CHECK (FALSE);

-- UPDATE: Only organizer can update status
CREATE POLICY "Organizers can update payment status"
ON payments FOR UPDATE TO authenticated
USING (
    tournament_entry_id IN (
        SELECT te.id FROM tournament_entries te
        JOIN categories c ON c.id = te.category_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);

-- ============================================
-- match_sets policies
-- ============================================

-- Drop existing policies if they exist (idempotent)
DROP POLICY IF EXISTS "Authenticated users can view match sets" ON match_sets;
DROP POLICY IF EXISTS "Match sets modified via scores trigger only" ON match_sets;
DROP POLICY IF EXISTS "Match sets update blocked" ON match_sets;
DROP POLICY IF EXISTS "Match sets delete blocked" ON match_sets;

-- SELECT: Any authenticated user
CREATE POLICY "Authenticated users can view match sets"
ON match_sets FOR SELECT TO authenticated
USING (TRUE);

-- INSERT: Blocked (via scores table trigger only)
CREATE POLICY "Match sets modified via scores trigger only"
ON match_sets FOR INSERT TO authenticated WITH CHECK (FALSE);

-- UPDATE: Blocked
CREATE POLICY "Match sets update blocked"
ON match_sets FOR UPDATE TO authenticated USING (FALSE);

-- DELETE: Blocked
CREATE POLICY "Match sets delete blocked"
ON match_sets FOR DELETE TO authenticated USING (FALSE);
