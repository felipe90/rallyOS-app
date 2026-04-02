-- Migration: Add elo_history table
-- Description: Creates the elo_history table for tracking ELO changes with proper schema, indexes, and RLS policies
-- Created as part of fix-elo-history-table change

-- 1. Create enum type for change types (idempotent)
DO $$ BEGIN
    CREATE TYPE elo_change_type AS ENUM (
        'MATCH_WIN',
        'MATCH_LOSS',
        'ADJUSTMENT',
        'TOURNAMENT_BONUS'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Create elo_history table (idempotent)
CREATE TABLE IF NOT EXISTS elo_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NOT NULL,
    sport_id UUID NOT NULL,
    match_id UUID,
    previous_elo INTEGER NOT NULL,
    new_elo INTEGER NOT NULL,
    elo_change INTEGER NOT NULL,
    change_type elo_change_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create indexes for efficient queries (idempotent)
CREATE INDEX IF NOT EXISTS idx_elo_history_person_sport ON elo_history (person_id, sport_id);
CREATE INDEX IF NOT EXISTS idx_elo_history_match_id ON elo_history (match_id);

-- 4. Add foreign key constraints (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'elo_history_person_id_fkey'
    ) THEN
        ALTER TABLE elo_history
            ADD CONSTRAINT elo_history_person_id_fkey
            FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'elo_history_sport_id_fkey'
    ) THEN
        ALTER TABLE elo_history
            ADD CONSTRAINT elo_history_sport_id_fkey
            FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'elo_history_match_id_fkey'
    ) THEN
        ALTER TABLE elo_history
            ADD CONSTRAINT elo_history_match_id_fkey
            FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 5. Enable RLS (idempotent)
ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;

-- 6. Create SELECT policy (idempotent - check if exists first)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Elo history is read only for users'
    ) THEN
        CREATE POLICY "Elo history is read only for users"
            ON elo_history FOR SELECT USING (true);
    END IF;
END $$;

-- 7. Grant permissions
GRANT ALL ON elo_history TO anon;
GRANT ALL ON elo_history TO authenticated;
GRANT ALL ON elo_history TO service_role;
