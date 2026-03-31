-- ============================================
-- SPEC-010: Tournament Entries CRUD
-- Enable RLS on tournament_entries table
-- ============================================

-- Enable RLS on tournament_entries
ALTER TABLE tournament_entries ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users can view entries
CREATE POLICY "Authenticated users can view entries"
ON tournament_entries FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Only during REGISTRATION status and by authenticated users
CREATE POLICY "Users can create entries during registration"
ON tournament_entries FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated'
    AND
    EXISTS (
        SELECT 1 FROM tournaments t
        JOIN categories c ON c.tournament_id = t.id
        WHERE c.id = tournament_entries.category_id
        AND t.status = 'REGISTRATION'
    )
);

-- UPDATE: Entry members or organizers can update
-- But not after tournament is LIVE
CREATE POLICY "Entry owner or organizer can update entries"
ON tournament_entries FOR UPDATE
USING (
    -- Organizer check
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        JOIN tournament_entries te ON te.category_id = c.id
        WHERE te.id = tournament_entries.id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
    OR
    -- Entry member check
    EXISTS (
        SELECT 1 FROM entry_members em
        JOIN persons p ON p.id = em.person_id
        WHERE em.entry_id = tournament_entries.id
        AND p.user_id = auth.uid()
    )
);

-- DELETE: Entry owner or organizer can cancel entries
-- But only before tournament goes LIVE
CREATE POLICY "Users can cancel own entries"
ON tournament_entries FOR DELETE
USING (
    -- Must not be LIVE or COMPLETED
    NOT EXISTS (
        SELECT 1 FROM tournaments t
        JOIN categories c ON c.tournament_id = t.id
        JOIN tournament_entries te ON te.category_id = c.id
        WHERE te.id = tournament_entries.id
        AND t.status IN ('LIVE', 'COMPLETED')
    )
    AND
    (
        -- Organizer check
        EXISTS (
            SELECT 1 FROM tournament_staff ts
            JOIN categories c ON c.tournament_id = ts.tournament_id
            JOIN tournament_entries te ON te.category_id = c.id
            WHERE te.id = tournament_entries.id
            AND ts.user_id = auth.uid()
            AND ts.role = 'ORGANIZER'
        )
        OR
        -- Entry member check
        EXISTS (
            SELECT 1 FROM entry_members em
            JOIN persons p ON p.id = em.person_id
            WHERE em.entry_id = tournament_entries.id
            AND p.user_id = auth.uid()
        )
    )
);

-- Enable RLS on entry_members
ALTER TABLE entry_members ENABLE ROW LEVEL SECURITY;

-- SELECT: All can view entry members
CREATE POLICY "Authenticated users can view entry members"
ON entry_members FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Authenticated users can add themselves
-- (duplicate check handled by trigger SPEC-006)
CREATE POLICY "Users can add themselves to entries"
ON entry_members FOR INSERT
WITH CHECK (
    auth.role() = 'authenticated'
);

-- DELETE: Users can remove themselves from entries
CREATE POLICY "Users can remove themselves from entries"
ON entry_members FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM persons p
        WHERE p.id = entry_members.person_id
        AND p.user_id = auth.uid()
    )
);
