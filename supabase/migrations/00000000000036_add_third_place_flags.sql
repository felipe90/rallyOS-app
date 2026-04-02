-- ============================================================
-- Migration: 00000000000036_add_third_place_flags
-- Purpose: Add third place match tracking flags to matches
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Add third place columns to matches
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE matches
ADD COLUMN IF NOT EXISTS third_place_pending BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS third_place_accepted BOOLEAN NULL;

-- Add comments for documentation
COMMENT ON COLUMN matches.third_place_pending IS 
'When TRUE, third place has been offered to players in this match';
COMMENT ON COLUMN matches.third_place_accepted IS 
'NULL = no response, TRUE = accepted, FALSE = rejected';

-- ═══════════════════════════════════════════════════════════════
-- Add RLS policies for third place flags
-- ═══════════════════════════════════════════════════════════════

-- Organizer can update third place flags
CREATE POLICY "Organizer can update third place flags"
ON matches FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = matches.category_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
);

-- Players can read third place flags for their matches
CREATE POLICY "Players can read third place flags"
ON matches FOR SELECT
USING (
    entry_a_id IN (
        SELECT em.entry_id FROM entry_members em
        JOIN persons p ON em.person_id = p.id
        WHERE p.user_id = auth.uid()
    )
    OR entry_b_id IN (
        SELECT em.entry_id FROM entry_members em
        JOIN persons p ON em.person_id = p.id
        WHERE p.user_id = auth.uid()
    )
);

COMMIT;
