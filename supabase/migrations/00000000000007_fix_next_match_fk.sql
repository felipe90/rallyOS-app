-- Migration: 00000000000007_fix_next_match_fk
-- Purpose: Make next_match_id FK deferrable to allow seed data loading

-- Drop existing FK constraint
ALTER TABLE matches DROP CONSTRAINT IF EXISTS matches_next_match_id_fkey;

-- Re-add as DEFERRABLE (allows self-referential FK during same transaction)
ALTER TABLE matches ADD CONSTRAINT matches_next_match_id_fkey 
    FOREIGN KEY (next_match_id) REFERENCES matches(id) 
    DEFERRABLE INITIALLY DEFERRED;
