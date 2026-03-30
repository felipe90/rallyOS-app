-- RallyOS: Database Schema Descriptions
-- Generated: 2026-03-30

-- ============================================
-- TABLAS CORE
-- ============================================

-- SPORTS: Disciplinas deportivas (tenis, padel, etc.)
CREATE TABLE sports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    scoring_system  sport_scoring_system DEFAULT 'POINTS',
    default_points_per_set   INT DEFAULT 21,
    default_best_of_sets     INT DEFAULT 3,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- TOURNAMENTS: Torneos/eventos
CREATE TABLE tournaments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id            UUID NOT NULL REFERENCES sports(id),
    name                TEXT NOT NULL,
    status              tournament_status DEFAULT 'DRAFT',
    handicap_enabled     BOOLEAN DEFAULT FALSE,
    use_differential    BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- CATEGORIES: Divisiones dentro de torneos (edad, nivel, etc.)
CREATE TABLE categories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id   UUID NOT NULL REFERENCES tournaments(id),
    name            TEXT NOT NULL,
    mode            game_mode DEFAULT 'SINGLES',
    points_override     INT,
    sets_override       INT,
    elo_min        INT DEFAULT 0,
    elo_max        INT DEFAULT 9999,
    bracket_system bracket_system DEFAULT 'SINGLE_ELIMINATION',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- PERSONS: Perfiles de usuarios/jugadores
CREATE TABLE persons (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users(id),  -- nullable para invitados
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    nickname    TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ESTADISTICAS Y ELO
-- ============================================

-- ATHLETE_STATS: Estadisticas por deporte
CREATE TABLE athlete_stats (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id       UUID NOT NULL REFERENCES persons(id),
    sport_id        UUID NOT NULL REFERENCES sports(id),
    current_elo     INT DEFAULT 1000,
    matches_played  INT DEFAULT 0,
    UNIQUE(person_id, sport_id)
);

-- ELO_HISTORY: Ledger inmutable de cambios ELO
CREATE TABLE elo_history (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id   UUID NOT NULL REFERENCES persons(id),
    sport_id    UUID NOT NULL REFERENCES sports(id),
    match_id    UUID REFERENCES matches(id),  -- nullable para ajustes manuales
    previous_elo    INT NOT NULL,
    new_elo        INT NOT NULL,
    elo_change     INT NOT NULL,
    change_type    elo_change_type NOT NULL,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);
-- ELO es inmutable: no UPDATE, no DELETE (ver RLS policy)

-- ============================================
-- TORNEOS
-- ============================================

-- TOURNAMENT_STAFF: Staff del torneo
CREATE TABLE tournament_staff (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id   UUID NOT NULL REFERENCES tournaments(id),
    user_id         UUID NOT NULL REFERENCES auth.users(id),
    role            TEXT NOT NULL,  -- ORGANIZER, REFEREE, ADMIN
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- TOURNAMENTS_ENTRIES: Inscripciones
CREATE TABLE tournament_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id     UUID NOT NULL REFERENCES categories(id),
    display_name    TEXT NOT NULL,
    current_handicap    INT DEFAULT 0,
    status          entry_status DEFAULT 'PENDING_PAYMENT',
    fee_amount_snap     INT,  -- Precio al momento de inscripcion
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ENTRY_MEMBERS: Miembros de un equipo/dupla
CREATE TABLE entry_members (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id    UUID NOT NULL REFERENCES tournament_entries(id),
    person_id   UUID NOT NULL REFERENCES persons(id),
    UNIQUE(entry_id, person_id)
);

-- ============================================
-- PARTIDOS Y SCORES
-- ============================================

-- MATCHES: Partido individual
CREATE TABLE matches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id     UUID NOT NULL REFERENCES categories(id),
    entry_a_id      UUID REFERENCES tournament_entries(id),
    entry_b_id      UUID REFERENCES tournament_entries(id),
    referee_id      UUID REFERENCES auth.users(id),
    next_match_id   UUID REFERENCES matches(id),  -- Linked list para bracket
    court_id        TEXT,
    status          match_status DEFAULT 'SCHEDULED',
    round_name      TEXT,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    local_updated_at    TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- SCORES: Score de un partido
CREATE TABLE scores (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id        UUID NOT NULL UNIQUE REFERENCES matches(id),
    current_set     INT DEFAULT 1,
    points_a        INT DEFAULT 0,
    points_b        INT DEFAULT 0,
    sets_json       JSONB DEFAULT '[]',  -- [{"a": 6, "b": 3}, {"a": 2, "b": 6}]
    local_updated_at    TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PAGOS
-- ============================================

-- PAYMENTS: Registros de pago
CREATE TABLE payments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_entry_id UUID NOT NULL REFERENCES tournament_entries(id),
    user_id             UUID REFERENCES auth.users(id),
    provider            TEXT,  -- stripe, mercadopago
    provider_txn_id      TEXT,
    amount              INT,  -- centavos
    currency            TEXT DEFAULT 'USD',
    status              payment_status DEFAULT 'REQUIRES_PAYMENT',
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ACTIVIDAD
-- ============================================

-- COMMUNITY_FEED: Feed de actividad
CREATE TABLE community_feed (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id   UUID NOT NULL REFERENCES tournaments(id),
    event_type      TEXT NOT NULL,
    payload_json    JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE sport_scoring_system AS ENUM ('POINTS', 'GAMES');
CREATE TYPE tournament_status AS ENUM ('DRAFT', 'REGISTRATION', 'CHECK_IN', 'LIVE', 'COMPLETED');
CREATE TYPE match_status AS ENUM ('SCHEDULED', 'CALLING', 'READY', 'LIVE', 'FINISHED', 'W_O', 'SUSPENDED');
CREATE TYPE game_mode AS ENUM ('SINGLES', 'DOUBLES', 'TEAMS');
CREATE TYPE bracket_system AS ENUM ('SINGLE_ELIMINATION', 'ROUND_ROBIN');
CREATE TYPE entry_status AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED');
CREATE TYPE elo_change_type AS ENUM ('MATCH_WIN', 'MATCH_LOSS', 'ADJUSTMENT');
CREATE TYPE payment_status AS ENUM ('REQUIRES_PAYMENT', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'REFUNDED');

-- ============================================
-- TRIGGERS
-- ============================================

-- Auto-asignar organizador al crear torneo
CREATE TRIGGER trg_tournament_created_assign_organizer
    AFTER INSERT ON tournaments
    FOR EACH ROW EXECUTE FUNCTION assign_tournament_organizer();

-- Proteccion contra time-tampering offline
CREATE TRIGGER trg_matches_conflict_resolution
    BEFORE UPDATE ON matches
    FOR EACH ROW EXECUTE FUNCTION check_offline_sync_conflict();

CREATE TRIGGER trg_scores_conflict_resolution
    BEFORE UPDATE ON scores
    FOR EACH ROW EXECUTE FUNCTION check_offline_sync_conflict();

-- Calcular ELO al terminar partido
CREATE TRIGGER trg_match_completion
    AFTER UPDATE ON matches
    FOR EACH ROW EXECUTE FUNCTION process_match_completion();

-- Avanzar bracket
CREATE TRIGGER trg_advance_bracket
    AFTER UPDATE ON matches
    FOR EACH ROW EXECUTE FUNCTION advance_bracket_winner();
