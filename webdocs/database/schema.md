# RallyOS: Database Schema

**Generated**: 2026-03-30  
> Para DDL completo ver [schema.sql](./schema.sql)

---

## Tablas Core

### SPORTS
```yaml
id:                   uuid
name:                 text
scoring_system:       sport_scoring_system
default_points_per_set: int
default_best_of_sets:   int
created_at:           timestamptz
```

### TOURNAMENTS
```yaml
id:               uuid
sport_id:         uuid FK → sports
name:             text
status:           tournament_status
handicap_enabled: boolean
use_differential: boolean
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
```

### PERSONS
```yaml
id:         uuid
user_id:    uuid FK → auth.users (nullable)
first_name: text
last_name:  text
nickname:   text
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
created_at:    timestamptz (inmutable)
```

---

## Tablas de Torneos

### TOURNAMENT_STAFF
```yaml
id:            uuid
tournament_id: uuid FK → tournaments
user_id:       uuid FK → auth.users
role:          text (ORGANIZER, REFEREE, ADMIN)
created_at:    timestamptz
```

### TOURNAMENT_ENTRIES
```yaml
id:               uuid
category_id:      uuid FK → categories
display_name:     text
current_handicap: int
status:           entry_status
fee_amount_snap:  int
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
court_id:        text
status:          match_status
round_name:      text
started_at:      timestamptz
ended_at:        timestamptz
local_updated_at: timestamptz (offline sync)
created_at:      timestamptz
```

### SCORES
```yaml
id:               uuid
match_id:         uuid FK → matches (unique)
current_set:      int
points_a:         int
points_b:         int
sets_json:        jsonb (historial de sets)
local_updated_at: timestamptz
created_at:       timestamptz
updated_at:       timestamptz
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

### COMMUNITY_FEED
```yaml
id:            uuid
tournament_id: uuid FK → tournaments
event_type:    text
payload_json:  jsonb
created_at:    timestamptz
```

---

## Enums

```yaml
sport_scoring_system: POINTS, GAMES
tournament_status:    DRAFT, REGISTRATION, CHECK_IN, LIVE, COMPLETED
match_status:        SCHEDULED, CALLING, READY, LIVE, FINISHED, W_O, SUSPENDED
game_mode:           SINGLES, DOUBLES, TEAMS
bracket_system:      SINGLE_ELIMINATION, ROUND_ROBIN
entry_status:       PENDING_PAYMENT, CONFIRMED, CANCELLED
elo_change_type:     MATCH_WIN, MATCH_LOSS, ADJUSTMENT
payment_status:     REQUIRES_PAYMENT, PROCESSING, SUCCEEDED, FAILED, REFUNDED
```

---

## Triggers

```yaml
trg_tournament_created_assign_organizer: tournaments, AFTER INSERT, Asigna creador como organizer
trg_matches_conflict_resolution:         matches,  BEFORE UPDATE, Protección time-tampering
trg_scores_conflict_resolution:         scores,   BEFORE UPDATE, Protección time-tampering
trg_match_completion:                   matches,  AFTER UPDATE, Calcula ELO
trg_advance_bracket:                    matches,  AFTER UPDATE, Avanza bracket
```

---

*Ver [ER Diagram](../architecture/ER_DIAGRAM) para relaciones visuales*
*Ver [schema.sql](./schema.sql) para DDL completo*
