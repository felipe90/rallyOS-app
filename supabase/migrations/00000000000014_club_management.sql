-- ============================================
-- SPEC-007: Club/Organization Management
-- Create clubs and club_members tables with RLS
-- ============================================

-- Create clubs table
CREATE TABLE clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    logo_url TEXT,
    owner_user_id UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create club_members table
CREATE TABLE club_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'MEMBER')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(club_id, person_id)
);

-- Enable RLS on clubs
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;

-- RLS policies for clubs
CREATE POLICY "Authenticated users can view clubs"
ON clubs FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Users can create clubs"
ON clubs FOR INSERT
WITH CHECK (auth.uid() = owner_user_id);

CREATE POLICY "Club owners can update clubs"
ON clubs FOR UPDATE
USING (auth.uid() = owner_user_id);

CREATE POLICY "Club owners can delete clubs"
ON clubs FOR DELETE
USING (auth.uid() = owner_user_id);

-- Enable RLS on club_members
ALTER TABLE club_members ENABLE ROW LEVEL SECURITY;

-- RLS policies for club_members
CREATE POLICY "Club members can view their clubs"
ON club_members FOR SELECT
USING (
    auth.uid() IN (
        SELECT c.owner_user_id FROM clubs c WHERE c.id = club_id
    )
    OR auth.uid() IN (
        SELECT p.user_id FROM persons p WHERE p.id = person_id
    )
);

CREATE POLICY "Club owners can add members"
ON club_members FOR INSERT
WITH CHECK (
    auth.uid() IN (
        SELECT c.owner_user_id FROM clubs c WHERE c.id = club_id
    )
);

CREATE POLICY "Club owners or members can remove themselves"
ON club_members FOR DELETE
USING (
    auth.uid() IN (
        SELECT c.owner_user_id FROM clubs c WHERE c.id = club_id
    )
    OR auth.uid() IN (
        SELECT p.user_id FROM persons p WHERE p.id = person_id
    )
);

-- Add club_id to tournament_entries (optional association)
ALTER TABLE tournament_entries 
ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES clubs(id);

-- Create index for club lookups
CREATE INDEX IF NOT EXISTS idx_club_members_club ON club_members(club_id);
CREATE INDEX IF NOT EXISTS idx_club_members_person ON club_members(person_id);
CREATE INDEX IF NOT EXISTS idx_tournament_entries_club ON tournament_entries(club_id);
