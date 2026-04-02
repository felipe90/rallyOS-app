-- ============================================================
-- RALLYOS: Fix Round Robin Group Name Constraint
-- Migration: 00000000000043_fix_rr_name_constraint.sql
-- ============================================================
-- The original constraint (char_length <= 10) is too restrictive.
-- Group names like "Grupo A - Primera" (18 chars) should be valid.
-- We increase to 50 chars which allows descriptive names while
-- still preventing abuse.
-- ============================================================

SET search_path TO public;

-- Drop the restrictive constraint
ALTER TABLE round_robin_groups DROP CONSTRAINT IF EXISTS name_length;

-- Add a more reasonable constraint
ALTER TABLE round_robin_groups ADD CONSTRAINT name_length CHECK (char_length(name) BETWEEN 1 AND 50);

-- Verify
SELECT 
    'round_robin_groups name constraint updated' as status,
    pg_get_constraintdef(oid) as new_constraint
FROM pg_constraint
WHERE conname = 'name_length'
AND conrelid = 'round_robin_groups'::regclass;
