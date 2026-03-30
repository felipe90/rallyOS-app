# RallyOS: Entity Relationship Diagram

**Generated**: 2026-03-30

---

## Complete ER Diagram

```mermaid
erDiagram
    SPORTS {
        uuid id PK
        text name
        sport_scoring_system scoring_system
        int default_points_per_set
        int default_best_of_sets
        timestamptz created_at
    }

    TOURNAMENTS {
        uuid id PK
        uuid sport_id FK
        text name
        tournament_status status
        boolean handicap_enabled
        boolean use_differential
        timestamptz created_at
    }

    CATEGORIES {
        uuid id PK
        uuid tournament_id FK
        text name
        game_mode mode
        int points_override
        int sets_override
        int elo_min
        int elo_max
        bracket_system bracket_system
        timestamptz created_at
    }

    PERSONS {
        uuid id PK
        uuid user_id FK "nullable"
        text first_name
        text last_name
        text nickname
        timestamptz created_at
    }

    USERS {
        uuid id PK "auth.users"
    }

    ATHLETE_STATS {
        uuid id PK
        uuid person_id FK
        uuid sport_id FK
        int current_elo
        int matches_played
    }

    TOURNAMENT_STAFF {
        uuid id PK
        uuid tournament_id FK
        uuid user_id FK
        text role
        timestamptz created_at
    }

    TOURNAMENT_ENTRIES {
        uuid id PK
        uuid category_id FK
        text display_name
        int current_handicap
        entry_status status
        int fee_amount_snap
        timestamptz created_at
    }

    ENTRY_MEMBERS {
        uuid id PK
        uuid entry_id FK
        uuid person_id FK
    }

    MATCHES {
        uuid id PK
        uuid category_id FK
        uuid entry_a_id FK "nullable"
        uuid entry_b_id FK "nullable"
        uuid referee_id FK "nullable"
        uuid next_match_id FK "nullable"
        text court_id
        match_status status
        text round_name
        timestamptz started_at
        timestamptz ended_at
        timestamptz local_updated_at
        timestamptz created_at
    }

    SCORES {
        uuid id PK
        uuid match_id FK "unique"
        int current_set
        int points_a
        int points_b
        jsonb sets_json
        timestamptz local_updated_at
        timestamptz created_at
        timestamptz updated_at
    }

    ELO_HISTORY {
        uuid id PK
        uuid person_id FK
        uuid sport_id FK
        uuid match_id FK "nullable"
        int previous_elo
        int new_elo
        int elo_change
        elo_change_type change_type
        timestamptz created_at
    }

    PAYMENTS {
        uuid id PK
        uuid tournament_entry_id FK
        uuid user_id FK "nullable"
        text provider
        text provider_txn_id
        int amount
        text currency
        payment_status status
        timestamptz created_at
        timestamptz updated_at
    }

    COMMUNITY_FEED {
        uuid id PK
        uuid tournament_id FK
        text event_type
        jsonb payload_json
        timestamptz created_at
    }

    %% Relationships
    SPORTS ||--o{ TOURNAMENTS : "defines"
    SPORTS ||--o{ ATHLETE_STATS : "tracks"
    SPORTS ||--o{ ELO_HISTORY : "records"

    TOURNAMENTS ||--o{ CATEGORIES : "contains"
    TOURNAMENTS ||--o{ TOURNAMENT_STAFF : "has"
    TOURNAMENTS ||--o{ COMMUNITY_FEED : "generates"

    CATEGORIES ||--o{ TOURNAMENT_ENTRIES : "registers"
    CATEGORIES ||--o{ MATCHES : "organizes"

    USERS ||--o{ PERSONS : "links to"
    PERSONS ||--o{ ATHLETE_STATS : "has"
    PERSONS ||--o{ ENTRY_MEMBERS : "belongs to"
    PERSONS ||--o{ TOURNAMENT_STAFF : "works as"
    PERSONS ||--o{ PAYMENTS : "pays"

    TOURNAMENT_ENTRIES ||--o{ ENTRY_MEMBERS : "composed of"
    TOURNAMENT_ENTRIES ||--o{ PAYMENTS : "has"

    MATCHES ||--|| SCORES : "has one"
    MATCHES ||--o{ MATCHES : "advances to" 
    MATCHES ||--o{ ELO_HISTORY : "generates"

    ELO_HISTORY }o--|| PERSONS : "for player"
    ELO_HISTORY }o--|| MATCHES : "from match"
```

---

## Cardinality Legend

```mermaid
erDiagram
    A ||--o{ B : "one-to-many"
    A ||--|| B : "one-to-one"
    A }o--o{ B : "many-to-many"
    A ||--{ B : "one-to-many (not null)"
```

---

## Enums Reference

| Enum | Values |
|------|--------|
| `sport_scoring_system` | POINTS, GAMES |
| `tournament_status` | DRAFT, REGISTRATION, CHECK_IN, LIVE, COMPLETED |
| `match_status` | SCHEDULED, CALLING, READY, LIVE, FINISHED, W_O, SUSPENDED |
| `game_mode` | SINGLES, DOUBLES, TEAMS |
| `bracket_system` | SINGLE_ELIMINATION, ROUND_ROBIN |
| `entry_status` | PENDING_PAYMENT, CONFIRMED, CANCELLED |
| `elo_change_type` | MATCH_WIN, MATCH_LOSS, ADJUSTMENT |
| `payment_status` | REQUIRES_PAYMENT, PROCESSING, SUCCEEDED, FAILED, REFUNDED |
