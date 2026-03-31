-- ============================================
-- SPEC-005: Person CRUD con RLS
-- Enable Row Level Security on persons table
-- ============================================

-- Enable RLS on persons table
ALTER TABLE persons ENABLE ROW LEVEL SECURITY;

-- SELECT: Anyone authenticated can view all persons
-- Needed for tournament registration (organizer needs to see players to add them)
CREATE POLICY "Persons are readable by authenticated users"
ON persons FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Users create own OR organizers create guests (NULL user_id)
CREATE POLICY "Users can create own person or guest"
ON persons FOR INSERT
WITH CHECK (
    auth.uid() = user_id
    OR user_id IS NULL
);

-- UPDATE: Users update only their own profile
CREATE POLICY "Users can update own person"
ON persons FOR UPDATE
USING (auth.uid() = user_id);

-- DELETE: Users delete only their own profile
CREATE POLICY "Users can delete own person"
ON persons FOR DELETE
USING (auth.uid() = user_id);
