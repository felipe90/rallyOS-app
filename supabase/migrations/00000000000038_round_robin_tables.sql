-- Migration: 00000000000038_round_robin_tables.sql
-- Round Robin Groups and Knockout Brackets Schema (SPORT-AGNOSTIC)
-- 
-- IMPORTANT: All tournament format rules are configured per-sport in
-- sports.scoring_config->tournament_format:
--   - group_size.min/max (default: 3-5)
--   - referee_mode (INTRA_GROUP, EXTERNAL, NONE, etc.)
--   - loser_referees_winner (true/false)
--   - advancement_count, has_third_place, etc.
--
-- Entities:
-- - round_robin_groups: Groups playing round-robin (size configurable per sport)
-- - group_members: Membership linking players to groups
-- - knockout_brackets: Brackets generated post-groups
-- - bracket_slots: Individual positions in the bracket

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE group_status AS ENUM ('PENDING', 'IN_PROGRESS', 'COMPLETED');

CREATE TYPE member_status AS ENUM ('ACTIVE', 'WALKED_OVER', 'DISQUALIFIED');

CREATE TYPE bracket_status AS ENUM ('PENDING', 'IN_PROGRESS', 'COMPLETED');

CREATE TYPE match_phase AS ENUM ('ROUND_ROBIN', 'KNOCKOUT', 'BRONZE', 'FINAL');

CREATE TYPE assignment_type AS ENUM ('AUTOMATIC', 'MANUAL', 'LOSER_ASSIGNED');

-- ============================================
-- TABLE: round_robin_groups
-- ============================================

CREATE TABLE round_robin_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    advancement_count INTEGER DEFAULT 2,
    status group_status DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_group_name_per_tournament UNIQUE (tournament_id, name),
    CONSTRAINT advancement_positive CHECK (advancement_count > 0),
    CONSTRAINT name_length CHECK (char_length(name) <= 10)
);

CREATE INDEX idx_rrg_tournament ON round_robin_groups(tournament_id);
CREATE INDEX idx_rrg_status ON round_robin_groups(status);

-- ============================================
-- TABLE: group_members
-- ============================================

CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES round_robin_groups(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES persons(id),
    entry_id UUID NOT NULL REFERENCES tournament_entries(id),
    seed INTEGER NOT NULL,
    status member_status DEFAULT 'ACTIVE',
    check_in_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_person_per_group UNIQUE (group_id, person_id),
    CONSTRAINT unique_entry_per_group UNIQUE (group_id, entry_id),
    CONSTRAINT seed_positive CHECK (seed > 0),
    CONSTRAINT unique_seed_per_group UNIQUE (group_id, seed)
);

CREATE INDEX idx_gm_group ON group_members(group_id);
CREATE INDEX idx_gm_person ON group_members(person_id);
CREATE INDEX idx_gm_entry ON group_members(entry_id);
CREATE INDEX idx_gm_status ON group_members(status);

-- ============================================
-- TABLE: knockout_brackets
-- ============================================

CREATE TABLE knockout_brackets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    status bracket_status DEFAULT 'PENDING',
    third_place_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT one_bracket_per_tournament UNIQUE (tournament_id)
);

CREATE INDEX idx_kb_tournament ON knockout_brackets(tournament_id);

-- ============================================
-- TABLE: bracket_slots
-- ============================================

CREATE TABLE bracket_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bracket_id UUID NOT NULL REFERENCES knockout_brackets(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    round INTEGER NOT NULL,
    round_name TEXT,
    entry_id UUID REFERENCES tournament_entries(id),
    seed_source TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_position_per_bracket UNIQUE (bracket_id, position),
    CONSTRAINT round_positive CHECK (round > 0),
    CONSTRAINT position_positive CHECK (position > 0)
);

CREATE INDEX idx_bs_bracket ON bracket_slots(bracket_id);
CREATE INDEX idx_bs_entry ON bracket_slots(entry_id);
CREATE INDEX idx_bs_round ON bracket_slots(round);

-- ============================================
-- UPDATED TABLE: matches
-- ============================================

ALTER TABLE matches ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES round_robin_groups(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS bracket_id UUID REFERENCES knockout_brackets(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS phase match_phase DEFAULT 'ROUND_ROBIN';
ALTER TABLE matches ADD COLUMN IF NOT EXISTS round_number INTEGER;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS next_match_id UUID REFERENCES matches(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS loser_assigned_referee UUID REFERENCES auth.users(id);

-- Indexes for new columns
CREATE INDEX IF NOT EXISTS idx_matches_group ON matches(group_id);
CREATE INDEX IF NOT EXISTS idx_matches_bracket ON matches(bracket_id);
CREATE INDEX IF NOT EXISTS idx_matches_phase ON matches(phase);
CREATE INDEX IF NOT EXISTS idx_matches_next ON matches(next_match_id) WHERE next_match_id IS NOT NULL;

-- ============================================
-- UPDATED TABLE: referee_assignments
-- ============================================

ALTER TABLE referee_assignments ADD COLUMN IF NOT EXISTS assignment_type assignment_type DEFAULT 'MANUAL';

-- ============================================
-- ADD TO tournament_status ENUM (if not exists)
-- Note: This is a PostgreSQL limitation - enum modifications require TYPE UPDATE
-- For now, we'll use application-level validation
-- The existing tournament_status enum: DRAFT, REGISTRATION, CHECK_IN, LIVE, COMPLETED
-- We need to add: PRE_TOURNAMENT, SUSPENDED, CANCELLED

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tournament_status') THEN
        CREATE TYPE tournament_status AS ENUM ('DRAFT', 'REGISTRATION', 'PRE_TOURNAMENT', 'CHECK_IN', 'LIVE', 'SUSPENDED', 'COMPLETED', 'CANCELLED');
    ELSE
        -- Check if PRE_TOURNAMENT exists, if not we need to handle it differently
        -- For now, let's assume it's already there from previous migrations
    END IF;
END $$;

-- ============================================
-- ADD round_bye TO group_members (for BYE tracking)
-- ============================================

ALTER TABLE group_members ADD COLUMN IF NOT EXISTS round_bye INTEGER;

-- ============================================
-- UPDATED athlete_stats (if matches_refereed doesn't exist)
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'athlete_stats' AND column_name = 'matches_refereed'
    ) THEN
        ALTER TABLE athlete_stats ADD COLUMN IF NOT EXISTS matches_refereed INTEGER DEFAULT 0;
    END IF;
END $$;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE round_robin_groups IS 'Round Robin groups for Table Tennis tournaments';
COMMENT ON TABLE group_members IS 'Membership of players in Round Robin groups';
COMMENT ON TABLE knockout_brackets IS 'Knockout bracket generated after Round Robin completion';
COMMENT ON TABLE bracket_slots IS 'Individual positions in knockout bracket';

COMMENT ON COLUMN round_robin_groups.advancement_count IS 'How many players advance to bracket from this group';
COMMENT ON COLUMN round_robin_groups.status IS 'PENDING: not started, IN_PROGRESS: matches playing, COMPLETED: all matches done';
COMMENT ON COLUMN group_members.seed IS 'Seeding position (1 = head of group), unique within group';
COMMENT ON COLUMN group_members.status IS 'ACTIVE: playing, WALKED_OVER: did not attend, DISQUALIFIED: removed';
COMMENT ON COLUMN matches.group_id IS 'FK to round_robin_groups if this match is part of RR phase';
COMMENT ON COLUMN matches.bracket_id IS 'FK to knockout_brackets if this match is part of KO phase';
COMMENT ON COLUMN matches.phase IS 'ROUND_ROBIN, KNOCKOUT, BRONZE, or FINAL';
COMMENT ON COLUMN matches.next_match_id IS 'The next match the WINNER will play';
COMMENT ON COLUMN matches.loser_assigned_referee IS 'User ID of loser, to be assigned as referee to next_match';
