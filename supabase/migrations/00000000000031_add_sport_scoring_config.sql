-- ============================================
-- Task 1: Add scoring_config column to sports table
-- ============================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Step 1: Add scoring_config JSONB column with default
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE sports
ADD COLUMN IF NOT EXISTS scoring_config JSONB NOT NULL DEFAULT '{
    "type": "generic",
    "points_per_set": 11,
    "best_of_sets": 3,
    "tie_break": {
        "enabled": true,
        "points": 7
    },
    "match_advantages": {
        "enabled": false,
        "min_difference": 2
    },
    "scoring_system": "standard",
    "win_condition": "points"
}'::jsonb;

-- ═══════════════════════════════════════════════════════════════
-- Step 2: Add index on sports(id) for scoring_config queries
-- Note: No specific index needed for JSONB column itself in PostgreSQL
-- The primary key index on id already exists and can be used for lookups
-- If specific JSONB field queries are needed, a GIN index can be added later
-- ═══════════════════════════════════════════════════════════════

-- Verify primary key index exists (should already be there from init)
-- We'll add a comment to document the indexing strategy
COMMENT ON INDEX sports_pkey IS 'Primary key index used for scoring_config lookups by sports(id)';

-- ═══════════════════════════════════════════════════════════════
-- Step 3: Add RLS policy for reading scoring_config
-- ═══════════════════════════════════════════════════════════════

-- The existing "Authenticated users can view sports" policy already allows
-- SELECT on sports table for authenticated users, which includes scoring_config
-- However, let's explicitly document that scoring_config is readable

-- Update existing policy comment to clarify scoring_config is included
COMMENT ON POLICY "Authenticated users can view sports" ON sports IS
'All authenticated users can view sports including scoring_config for tournament setup';

-- For explicit clarity, we can also add a column-specific policy if needed
-- (not required since RLS operates at row level, not column level)

COMMIT;