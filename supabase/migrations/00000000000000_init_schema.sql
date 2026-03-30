-- ############################################################
-- # RALLYOS DATABASE SCHEMA V2.0
-- # Architecture: Multi-Sport, 3NF, Elo-Ledger, Bracket-Aware
-- ############################################################

-- 1. ENUMERATED TYPES (State Machines)
CREATE TYPE sport_scoring_system AS ENUM ('POINTS', 'GAMES');
CREATE TYPE tournament_status AS ENUM ('DRAFT', 'REGISTRATION', 'CHECK_IN', 'LIVE', 'COMPLETED');
CREATE TYPE match_status AS ENUM ('SCHEDULED', 'CALLING', 'READY', 'LIVE', 'FINISHED', 'W_O', 'SUSPENDED');
CREATE TYPE game_mode AS ENUM ('SINGLES', 'DOUBLES', 'TEAMS');

-- 2. MASTER TABLES
CREATE TABLE sports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    scoring_system sport_scoring_system NOT NULL,
    default_points_per_set INTEGER DEFAULT 11,
    default_best_of_sets INTEGER DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID REFERENCES sports(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    status tournament_status DEFAULT 'DRAFT',
    handicap_enabled BOOLEAN DEFAULT TRUE,
    use_differential BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    mode game_mode DEFAULT 'SINGLES',
    points_override INTEGER,
    sets_override INTEGER,
    elo_min INTEGER,
    elo_max INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. IDENTITY AND PERSONS
CREATE TABLE persons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Link with Supabase Auth
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    nickname TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE athlete_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    sport_id UUID REFERENCES sports(id) ON DELETE CASCADE,
    current_elo INTEGER DEFAULT 1000,
    matches_played INTEGER DEFAULT 0,
    UNIQUE(person_id, sport_id)
);

-- 3.5 TOURNAMENT ROLES (STAFF & AUTHORIZATION)
CREATE TABLE tournament_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('ORGANIZER', 'EXTERNAL_REFEREE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tournament_id, user_id)
);

-- 4. ENTRIES (EPHEMERAL TEAMS)
CREATE TABLE tournament_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    display_name TEXT, -- If null, frontend concatenates members
    current_handicap INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE entry_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID REFERENCES tournament_entries(id) ON DELETE CASCADE,
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    UNIQUE(entry_id, person_id)
);

-- 5. MATCH LOGISTICS
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    entry_a_id UUID REFERENCES tournament_entries(id) ON DELETE SET NULL,
    entry_b_id UUID REFERENCES tournament_entries(id) ON DELETE SET NULL,
    referee_id UUID REFERENCES auth.users(id), -- Direct FK to Auth for RLS validation
    court_id TEXT, -- Table/Court identifier
    status match_status DEFAULT 'SCHEDULED',
    next_match_id UUID REFERENCES matches(id), -- Bracket Logic
    round_name TEXT, -- e.g. 'Semifinal'
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. ATOMIC SCORE (1:1 Relationship with Match)
CREATE TABLE scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE UNIQUE,
    current_set INTEGER DEFAULT 1,
    points_a INTEGER DEFAULT 0,
    points_b INTEGER DEFAULT 0,
    sets_json JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. PAYMENT ENGINE (SaaS MONETIZATION)
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_entry_id UUID REFERENCES tournament_entries(id) ON DELETE RESTRICT,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    provider TEXT CHECK (provider IN ('STRIPE', 'MERCADO_PAGO')),
    provider_txn_id TEXT,
    amount INTEGER NOT NULL,
    currency TEXT DEFAULT 'USD',
    status TEXT CHECK (status IN ('REQUIRES_PAYMENT', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'REFUNDED')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. SOCIAL FEED & ENGAGEMENT (EVENT-DRIVEN)
CREATE TABLE community_feed (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL, -- e.g. 'UPSET', 'CHAMPION', 'MATCH_START'
    payload_json JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);