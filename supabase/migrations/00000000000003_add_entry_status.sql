-- Migration: 00000000000003_add_entry_status
-- Adds entry status tracking for tournament payment lifecycle
-- Author: SDD Apply Phase
-- Created: 2026-03-30

-- ============================================================
-- 1. CREATE ENUM TYPE
-- ============================================================
CREATE TYPE entry_status AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED');

-- ============================================================
-- 2. ADD COLUMNS TO tournament_entries
-- ============================================================
ALTER TABLE tournament_entries 
ADD COLUMN IF NOT EXISTS status entry_status DEFAULT 'PENDING_PAYMENT' NOT NULL;

ALTER TABLE tournament_entries 
ADD COLUMN IF NOT EXISTS fee_amount_snap INTEGER;

-- ============================================================
-- 3. ADD RLS POLICY FOR STATUS UPDATES
-- ============================================================
ALTER TABLE tournament_entries ENABLE ROW LEVEL SECURITY;

-- UPDATE policy: entry owner or organizer can update status
CREATE POLICY "Entry owner or organizer can update status"
ON tournament_entries
FOR UPDATE
USING (
    -- User owns the entry (via entry_members -> persons -> auth.users)
    EXISTS (
        SELECT 1 FROM entry_members em
        JOIN persons p ON em.person_id = p.id
        WHERE em.entry_id = tournament_entries.id
        AND p.user_id = auth.uid()
    )
    OR
    -- User is organizer of the tournament
    EXISTS (
        SELECT 1 FROM categories c
        JOIN tournament_staff ts ON c.tournament_id = ts.tournament_id
        WHERE c.id = tournament_entries.category_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
);

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================
