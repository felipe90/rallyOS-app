-- ============================================================
-- RALLYOS: RLS Policies for Round Robin Tables
-- Migration: 00000000000042_rr_rls_policies.sql
-- ============================================================
-- These tables were added without RLS policies, creating a
-- security gap. This migration adds proper row-level security.
--
-- Security Model:
-- - Only ORGANIZER role can modify round_robin_groups and related tables
-- - Authenticated users can read (view brackets/group members)
-- - The create_round_robin_group RPC handles authorization via auth.uid()
-- ============================================================

SET search_path TO public;

-- ─────────────────────────────────────────────────────────
-- 1. ENABLE RLS ON ALL RR TABLES
-- ─────────────────────────────────────────────────────────

ALTER TABLE round_robin_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE knockout_brackets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bracket_slots ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────
-- 2. ROUND_ROBIN_GROUPS POLICIES
-- ─────────────────────────────────────────────────────────

-- SELECT: Organizers of the tournament + authenticated users (for viewing)
CREATE POLICY "Organizers can view round robin groups"
ON round_robin_groups FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = round_robin_groups.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- INSERT: Only via RPC with ORGANIZER check (but add policy for direct inserts)
CREATE POLICY "Organizers can create round robin groups"
ON round_robin_groups FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = round_robin_groups.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- UPDATE: Only organizers
CREATE POLICY "Organizers can update round robin groups"
ON round_robin_groups FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = round_robin_groups.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- DELETE: Only organizers
CREATE POLICY "Organizers can delete round robin groups"
ON round_robin_groups FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = round_robin_groups.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- ─────────────────────────────────────────────────────────
-- 3. GROUP_MEMBERS POLICIES
-- ─────────────────────────────────────────────────────────

-- SELECT: Organizers of the tournament
CREATE POLICY "Organizers can view group members"
ON group_members FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN round_robin_groups rrg ON rrg.tournament_id = ts.tournament_id
    WHERE rrg.id = group_members.group_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- INSERT: Only organizers
CREATE POLICY "Organizers can add group members"
ON group_members FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN round_robin_groups rrg ON rrg.tournament_id = ts.tournament_id
    WHERE rrg.id = group_members.group_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- UPDATE: Only organizers
CREATE POLICY "Organizers can update group members"
ON group_members FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN round_robin_groups rrg ON rrg.tournament_id = ts.tournament_id
    WHERE rrg.id = group_members.group_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- DELETE: Only organizers
CREATE POLICY "Organizers can remove group members"
ON group_members FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN round_robin_groups rrg ON rrg.tournament_id = ts.tournament_id
    WHERE rrg.id = group_members.group_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- ─────────────────────────────────────────────────────────
-- 4. KNOCKOUT_BRACKETS POLICIES
-- ─────────────────────────────────────────────────────────

-- SELECT: Organizers + authenticated (viewing)
CREATE POLICY "Organizers can view knockout brackets"
ON knockout_brackets FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = knockout_brackets.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- INSERT: Only organizers
CREATE POLICY "Organizers can create knockout brackets"
ON knockout_brackets FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = knockout_brackets.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- UPDATE: Only organizers
CREATE POLICY "Organizers can update knockout brackets"
ON knockout_brackets FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = knockout_brackets.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- DELETE: Only organizers
CREATE POLICY "Organizers can delete knockout brackets"
ON knockout_brackets FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    WHERE ts.tournament_id = knockout_brackets.tournament_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- ─────────────────────────────────────────────────────────
-- 5. BRACKET_SLOTS POLICIES
-- ─────────────────────────────────────────────────────────

-- SELECT: Organizers
CREATE POLICY "Organizers can view bracket slots"
ON bracket_slots FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN knockout_brackets kb ON kb.tournament_id = ts.tournament_id
    WHERE kb.id = bracket_slots.bracket_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- INSERT: Only organizers
CREATE POLICY "Organizers can create bracket slots"
ON bracket_slots FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN knockout_brackets kb ON kb.tournament_id = ts.tournament_id
    WHERE kb.id = bracket_slots.bracket_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- UPDATE: Only organizers
CREATE POLICY "Organizers can update bracket slots"
ON bracket_slots FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN knockout_brackets kb ON kb.tournament_id = ts.tournament_id
    WHERE kb.id = bracket_slots.bracket_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- DELETE: Only organizers
CREATE POLICY "Organizers can delete bracket slots"
ON bracket_slots FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_staff ts
    JOIN knockout_brackets kb ON kb.tournament_id = ts.tournament_id
    WHERE kb.id = bracket_slots.bracket_id
    AND ts.user_id = auth.uid()
    AND ts.role = 'ORGANIZER'
    AND ts.status = 'ACTIVE'
  )
);

-- ─────────────────────────────────────────────────────────
-- 6. VERIFICATION
-- ─────────────────────────────────────────────────────────

-- Verify RLS is enabled on all tables
SELECT 
  'round_robin_groups' as table_name,
  relrowsecurity as rls_enabled
FROM pg_class
WHERE relname = 'round_robin_groups'
UNION ALL
SELECT 
  'group_members' as table_name,
  relrowsecurity
FROM pg_class
WHERE relname = 'group_members'
UNION ALL
SELECT 
  'knockout_brackets' as table_name,
  relrowsecurity
FROM pg_class
WHERE relname = 'knockout_brackets'
UNION ALL
SELECT 
  'bracket_slots' as table_name,
  relrowsecurity
FROM pg_class
WHERE relname = 'bracket_slots';

-- Count policies created
SELECT 
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('round_robin_groups', 'group_members', 'knockout_brackets', 'bracket_slots')
GROUP BY tablename
ORDER BY tablename;

-- ============================================================
-- END OF MIGRATION
-- ============================================================
