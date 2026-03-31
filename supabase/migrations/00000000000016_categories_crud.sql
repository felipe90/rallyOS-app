-- ============================================
-- SPEC-009: Categories CRUD con RLS
-- Enable RLS on categories table
-- ============================================

-- Enable RLS on categories
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users can view categories
CREATE POLICY "Authenticated users can view categories"
ON categories FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Only organizers can create categories
CREATE POLICY "Organizers can create categories"
ON categories FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = categories.tournament_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
);

-- UPDATE: Only organizers can update categories
-- And only if tournament is not LIVE
CREATE POLICY "Organizers can update categories"
ON categories FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN tournaments t ON t.id = ts.tournament_id
        WHERE ts.tournament_id = categories.tournament_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND t.status NOT IN ('LIVE', 'COMPLETED') -- Cannot modify during tournament
    )
);

-- DELETE: Only organizers can delete empty categories
CREATE POLICY "Organizers can delete empty categories"
ON categories FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN tournaments t ON t.id = ts.tournament_id
        WHERE ts.tournament_id = categories.tournament_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND t.status NOT IN ('LIVE', 'COMPLETED')
    )
    AND
    -- Category must have no entries
    NOT EXISTS (
        SELECT 1 FROM tournament_entries te
        WHERE te.category_id = categories.id
    )
);

-- Function to validate no entries exist before delete
CREATE OR REPLACE FUNCTION validate_category_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tournament_entries te
        WHERE te.category_id = OLD.id
    ) THEN
        RAISE EXCEPTION 'Cannot delete category with registered entries';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_category_delete ON categories;
CREATE TRIGGER trg_validate_category_delete
    BEFORE DELETE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION validate_category_delete();
