# RallyOS: Database Schema

**Generated**: 2026-03-31 (Post-Architectural Overhaul)  
**Last Updated**: 2026-04-02 (Sport-Specific Scoring Rules Engine + Tests)

> Para DDL completo ver las migraciones en `supabase/migrations/`

---

## Tablas Core

### SPORTS
```yaml
id:                   uuid
name:                 text
scoring_system:       sport_scoring_system
default_points_per_set: int
default_best_of_sets:   int
scoring_config:        jsonb  # NEW: Sport-specific scoring rules
created_at:           timestamptz
```

**scoring_config JSONB structure:**
```json
{
  "type": "standard|rally|tennis_15_30_40",
  "points_per_set": 11,
  "best_of_sets": 5,
  "win_by_2": true,
  "win_by_2_games": true,
  "games_to_win_set": 6,
  "tie_break": { "enabled": true, "at": 6, "points": 7 },
  "has_super_tiebreak": false,
  "super_tiebreak_points": 10,
  "golden_point": { "enabled": true, "at": 40 },
  "deuce_at": 10,
  "min_difference": 2
}
```

### TOURNAMENTS
```yaml
id:               uuid
sport_id:         uuid FK → sports
name:             text
status:           tournament_status
handicap_enabled: boolean
use_differential: boolean
club_id:          uuid FK → clubs (optional)
created_at:       timestamptz
```

### CATEGORIES
```yaml
id:             uuid
tournament_id:  uuid FK → tournaments
name:           text
mode:           game_mode
points_override: int
sets_override:   int
elo_min:        int
elo_max:        int
bracket_system: bracket_system
created_at:     timestamptz
```

### PERSONS
```yaml
id:         uuid
user_id:    uuid FK → auth.users (unique, 1:1, nullable for shadow profiles)
first_name: text
last_name:  text
nickname:   text
nationality_country_id: uuid FK → countries
created_at:  timestamptz
```

---

## Tablas de Estadísticas

### ATHLETE_STATS
```yaml
id:             uuid
person_id:      uuid FK → persons
sport_id:       uuid FK → sports
current_elo:    int
matches_played: int
matches_refereed: int  # NEW: For round-robin balancing
rank:           athlete_rank (BRONZE, SILVER, GOLD, PLATINUM, DIAMOND)
UNIQUE(person_id, sport_id)
```

### ELO_HISTORY *(Ledger append-only)*
```yaml
id:           uuid
person_id:    uuid FK → persons
sport_id:     uuid FK → sports
match_id:     uuid FK → matches (nullable)
previous_elo:  int
new_elo:      int
elo_change:    int
change_type:   elo_change_type
opponent_elo_snap: int (for audit)
created_at:    timestamptz (inmutable)
```

---

## Tablas de Torneos

### TOURNAMENT_STAFF *(ENHANCED)*
```yaml
id:            uuid
tournament_id: uuid FK → tournaments
user_id:       uuid FK → auth.users
role:          staff_role (ORGANIZER, EXTERNAL_REFEREE, PLAYER_REFEREE)
status:        staff_status (PENDING, ACTIVE, REJECTED, REVOKED)  # NEW
invite_mode:   boolean DEFAULT FALSE  # NEW: true = invitation workflow
invited_by:    uuid FK → auth.users   # NEW: Who sent the invitation
expires_at:    timestamptz            # NEW: For invitation expiration
created_at:    timestamptz
UNIQUE(tournament_id, user_id)
```

### TOURNAMENT_ENTRIES
```yaml
id:               uuid
category_id:      uuid FK → categories
display_name:     text
current_handicap: int
status:           entry_status
fee_amount_snap:  int
checked_in_at:    timestamptz  # NEW: For player-as-referee eligibility
created_at:       timestamptz
```

### ENTRY_MEMBERS
```yaml
id:        uuid
entry_id:  uuid FK → tournament_entries
person_id: uuid FK → persons
```

---

## Tablas de Partidos

### MATCHES
```yaml
id:              uuid
category_id:     uuid FK → categories
entry_a_id:     uuid FK → tournament_entries (nullable)
entry_b_id:      uuid FK → tournament_entries (nullable)
referee_id:      uuid FK → auth.users (nullable)
next_match_id:   uuid FK → matches (nullable) - Linked List
winner_to_slot:  char(1) 'A' or 'B' (Deterministic Brackets)
pin_code:        text (4-digit, security)
court_id:        text
status:          match_status
round_name:      text
third_place_pending: boolean DEFAULT FALSE  # NEW
third_place_accepted: boolean NULL        # NEW
started_at:      timestamptz
ended_at:        timestamptz
created_at:      timestamptz
```

### SCORES
```yaml
id:               uuid
match_id:         uuid FK → matches (unique)
current_set:      int
points_a:         int
points_b:         int
created_at:       timestamptz
updated_at:       timestamptz
```

### MATCH_SETS (Normalized)
```yaml
id:               uuid
match_id:         uuid FK → matches
set_number:       int
points_a:         int
points_b:         int
is_finished:      boolean
created_at:       timestamptz
updated_at:       timestamptz
UNIQUE(match_id, set_number)
```

---

## Tablas de Pagos

### PAYMENTS
```yaml
id:                   uuid
tournament_entry_id:  uuid FK → tournament_entries
user_id:              uuid FK → auth.users (nullable)
provider:             text (stripe, mercadopago)
provider_txn_id:      text
amount:               int (centavos)
currency:             text (USD, ARS)
status:               payment_status
created_at:           timestamptz
updated_at:           timestamptz
```

---

## Tablas de Actividad

### COUNTRIES (L10N)
```yaml
id:              uuid
iso_code:        text UNIQUE (CO, AR, ES, etc)
name:            text
currency_code:   text
flag_emoji:      text
created_at:      timestamptz
```

### ACHIEVEMENTS (Gamification)
```yaml
id:              uuid
code:            text UNIQUE
name:            text
description:     text
icon_slug:       text
created_at:      timestamptz
```

### PLAYER_ACHIEVEMENTS
```yaml
id:              uuid
person_id:       uuid FK → persons
achievement_id:  uuid FK → achievements
earned_at:       timestamptz
UNIQUE(person_id, achievement_id)
```

### COMMUNITY_FEED
```yaml
id:            uuid
tournament_id: uuid FK → tournaments
event_type:    text
payload_json:  jsonb
created_at:    timestamptz
```

---

## Tablas de Staff & Player-As-Referee *(NEW)*

### REFEREE_VOLUNTEERS
```yaml
id:            uuid
tournament_id: uuid FK → tournaments
person_id:     uuid FK → persons
user_id:       uuid FK → auth.users
is_active:     boolean DEFAULT FALSE
created_at:    timestamptz
updated_at:    timestamptz
UNIQUE(tournament_id, person_id)
```

### REFEREE_ASSIGNMENTS
```yaml
id:             uuid
match_id:       uuid FK → matches (unique)
user_id:        uuid FK → auth.users
assigned_by:    uuid FK → auth.users (nullable)
is_suggested:   boolean DEFAULT FALSE  # True if auto-generated
is_confirmed:   boolean DEFAULT FALSE  # True if organizer confirmed
created_at:     timestamptz
```

### CLUBS
```yaml
id:            uuid
name:          text
country_id:    uuid FK → countries
owner_user_id: uuid FK → auth.users (nullable)
created_at:    timestamptz
```

---

## Enums

```yaml
# Existing Enums
athlete_rank:        BRONZE, SILVER, GOLD, PLATINUM, DIAMOND
sport_scoring_system: POINTS, GAMES
tournament_status:    DRAFT, REGISTRATION, CHECK_IN, LIVE, COMPLETED
match_status:        SCHEDULED, CALLING, READY, LIVE, FINISHED, W_O, SUSPENDED
game_mode:           SINGLES, DOUBLES, TEAMS
bracket_system:      SINGLE_ELIMINATION, ROUND_ROBIN
entry_status:       PENDING_PAYMENT, CONFIRMED, CANCELLED
elo_change_type:     MATCH_WIN, MATCH_LOSS, ADJUSTMENT
payment_status:     REQUIRES_PAYMENT, PROCESSING, SUCCEEDED, FAILED, REFUNDED

# NEW Enums (v2)
staff_role:          ORGANIZER, EXTERNAL_REFEREE, PLAYER_REFEREE
staff_status:        PENDING, ACTIVE, REJECTED, REVOKED
```

---

## Triggers

```yaml
# Existing Triggers
trg_update_athlete_rank:          athlete_stats, BEFORE UPDATE, Actualiza Rango (BRONZE-DIAMOND)
trg_generate_match_pin:           matches, BEFORE INSERT, Genera PIN de 4 dígitos
trg_match_completion:             matches, AFTER UPDATE, REAL ELO Engine (Set comparison)
trg_advance_bracket:              matches, AFTER UPDATE, Deterministic Bracket (winner_to_slot)
trg_scores_conflict_resolution:   scores, BEFORE UPDATE, Protección time-tampering (Offline Sync)
trg_check_single_active_staff:    tournament_staff, BEFORE INSERT/UPDATE, Solo un ACTIVE por usuario

# NEW Triggers (v2)
trg_update_referee_stats:         referee_assignments, AFTER UPDATE, Incrementa matches_refereed

# NEW Triggers (Sport Scoring)
trg_validate_score:             scores, BEFORE INSERT/UPDATE, Valida scores contra reglas del deporte
```

---

## RPCs (Functions)

### Staff Management *(NEW)*
```yaml
assign_staff(p_tournament_id, p_user_id, p_role, p_invite_mode)
  → tournament_staff
  → Assigns staff directly or creates invitation

invite_staff(p_tournament_id, p_user_id, p_role)
  → tournament_staff
  → Convenience wrapper for invitation mode

accept_invitation(p_tournament_id)
  → tournament_staff
  → Changes PENDING → ACTIVE

reject_invitation(p_tournament_id)
  → tournament_staff
  → Changes PENDING → REJECTED

revoke_staff(p_tournament_id, p_target_user_id)
  → VOID
  → Changes status → REVOKED

toggle_referee_volunteer(p_tournament_id, p_is_active)
  → VOID
  → Creates/updates referee_volunteers + tournament_staff
```

### Referee Assignment *(NEW)*
```yaml
generate_referee_suggestions(p_category_id)
  → TABLE(match_id UUID, user_id UUID)
  → Auto-suggests referees using round-robin

confirm_referee_assignment(p_match_id, p_user_id, p_is_organizer_override)
  → referee_assignments
  → Confirms suggestion or manual assignment

clear_match_referee(p_match_id)
  → VOID
  → Removes referee from match
```

---

## Funciones de Scoring *(NEW)*

### validate_score()
```yaml
validate_score(p_match_id UUID, p_points_a INTEGER, p_points_b INTEGER)
  → BOOLEAN
  → Valida que el score cumpla las reglas del sport
  → Lanza excepción si inválido
```

### calculate_game_winner()
```yaml
calculate_game_winner(p_score_a INTEGER, p_score_b INTEGER, p_scoring_config JSONB)
  → CHAR(1) ('A' | 'B' | NULL)
  → Calcula ganador de un game considerando:
  → - Tennis 15-30-40 (deuce/advantage)
  - TT/Pickleball 11-point (deuce a 10-10)
  - Golden point para Padel
```

### calculate_set_winner()
```yaml
calculate_set_winner(p_sets JSONB, p_scoring_config JSONB)
  → CHAR(1) ('A' | 'B' | NULL)
  → Calcula ganador de un set considerando:
  → - Tiebreak detection (ej: 6-6)
  - Super tiebreak (10 puntos)
```

### is_tiebreak()
```yaml
is_tiebreak(p_game_a INTEGER, p_game_b INTEGER, p_scoring_config JSONB)
  → BOOLEAN
  → Detecta si los scores indican situación de tiebreak
```

---

*Ver [ER Diagram](../architecture/ER_DIAGRAM) para relaciones visuales*
*Ver `supabase/migrations/` para DDL completo*
