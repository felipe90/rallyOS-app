# RallyOS: Database Schema

**Generated**: 2026-03-30

---

## Tablas Core

### SPORTS
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `name` | text | Nombre del deporte |
| `scoring_system` | sport_scoring_system | POINTS o GAMES |
| `default_points_per_set` | int | Puntos por set |
| `default_best_of_sets` | int | Mejor de N sets |
| `created_at` | timestamptz | Timestamp |

### TOURNAMENTS
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `sport_id` | uuid | FK → sports |
| `name` | text | Nombre |
| `status` | tournament_status | DRAFT, REGISTRATION, CHECK_IN, LIVE, COMPLETED |
| `handicap_enabled` | boolean | Hándicap activado |
| `use_differential` | boolean | Usar differential ELO |
| `created_at` | timestamptz | Timestamp |

### CATEGORIES
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `tournament_id` | uuid | FK → tournaments |
| `name` | text | Nombre (ej: "Men's Singles") |
| `mode` | game_mode | SINGLES, DOUBLES, TEAMS |
| `points_override` | int | Puntos por set (override) |
| `sets_override` | int | Mejor de N sets (override) |
| `elo_min` | int | ELO mínimo para participar |
| `elo_max` | int | ELO máximo para participar |
| `bracket_system` | bracket_system | SINGLE_ELIMINATION, ROUND_ROBIN |

### PERSONS
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `user_id` | uuid | FK → auth.users (nullable) |
| `first_name` | text | Nombre |
| `last_name` | text | Apellido |
| `nickname` | text | Apodo |
| `created_at` | timestamptz | Timestamp |

---

## Tablas de Estadísticas

### ATHLETE_STATS
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `person_id` | uuid | FK → persons |
| `sport_id` | uuid | FK → sports |
| `current_elo` | int | ELO actual |
| `matches_played` | int | Partidos jugados |

### ELO_HISTORY *(Ledger append-only)*
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `person_id` | uuid | FK → persons |
| `sport_id` | uuid | FK → sports |
| `match_id` | uuid | FK → matches (nullable) |
| `previous_elo` | int | ELO antes del cambio |
| `new_elo` | int | ELO después del cambio |
| `elo_change` | int | Diferencia (+/-) |
| `change_type` | elo_change_type | MATCH_WIN, MATCH_LOSS, ADJUSTMENT |
| `created_at` | timestamptz | Timestamp (inmutable) |

---

## Tablas de Torneos

### TOURNAMENT_STAFF
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `tournament_id` | uuid | FK → tournaments |
| `user_id` | uuid | FK → auth.users |
| `role` | text | ORGANIZER, REFEREE, ADMIN |
| `created_at` | timestamptz | Timestamp |

### TOURNAMENT_ENTRIES
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `category_id` | uuid | FK → categories |
| `display_name` | text | Nombre del equipo/jugador |
| `current_handicap` | int | Hándicap actual |
| `status` | entry_status | PENDING_PAYMENT, CONFIRMED, CANCELLED |
| `fee_amount_snap` | int | Precio bloqueado al registrarse |
| `created_at` | timestamptz | Timestamp |

### ENTRY_MEMBERS
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `entry_id` | uuid | FK → tournament_entries |
| `person_id` | uuid | FK → persons |

---

## Tablas de Partidos

### MATCHES
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `category_id` | uuid | FK → categories |
| `entry_a_id` | uuid | FK → tournament_entries (nullable) |
| `entry_b_id` | uuid | FK → tournament_entries (nullable) |
| `referee_id` | uuid | FK → auth.users (nullable) |
| `next_match_id` | uuid | FK → matches (nullable) - Linked List |
| `court_id` | text | Identificador de cancha |
| `status` | match_status | SCHEDULED, CALLING, READY, LIVE, FINISHED, W_O, SUSPENDED |
| `round_name` | text | Ronda (ej: "Quarterfinals") |
| `started_at` | timestamptz | Inicio del partido |
| `ended_at` | timestamptz | Fin del partido |
| `local_updated_at` | timestamptz | Para sync offline |
| `created_at` | timestamptz | Timestamp |

### SCORES
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `match_id` | uuid | FK → matches (unique) |
| `current_set` | int | Set actual |
| `points_a` | int | Puntos entry A |
| `points_b` | int | Puntos entry B |
| `sets_json` | jsonb | Historial de sets [{"a": 6, "b": 3}, ...] |
| `local_updated_at` | timestamptz | Para sync offline |
| `created_at` | timestamptz | Timestamp |
| `updated_at` | timestamptz | Timestamp |

---

## Tablas de Pagos

### PAYMENTS
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `tournament_entry_id` | uuid | FK → tournament_entries |
| `user_id` | uuid | FK → auth.users (nullable) |
| `provider` | text | stripe, mercadopago |
| `provider_txn_id` | text | ID de transacción externa |
| `amount` | int | Monto en centavos |
| `currency` | text | Moneda (USD, ARS) |
| `status` | payment_status | REQUIRES_PAYMENT, PROCESSING, SUCCEEDED, FAILED, REFUNDED |
| `created_at` | timestamptz | Timestamp |
| `updated_at` | timestamptz | Timestamp |

---

## Tablas de Actividad

### COMMUNITY_FEED
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | uuid | PK |
| `tournament_id` | uuid | FK → tournaments |
| `event_type` | text | Tipo de evento |
| `payload_json` | jsonb | Datos del evento |
| `created_at` | timestamptz | Timestamp |

---

## Enums

| Enum | Valores |
|------|---------|
| `sport_scoring_system` | POINTS, GAMES |
| `tournament_status` | DRAFT, REGISTRATION, CHECK_IN, LIVE, COMPLETED |
| `match_status` | SCHEDULED, CALLING, READY, LIVE, FINISHED, W_O, SUSPENDED |
| `game_mode` | SINGLES, DOUBLES, TEAMS |
| `bracket_system` | SINGLE_ELIMINATION, ROUND_ROBIN |
| `entry_status` | PENDING_PAYMENT, CONFIRMED, CANCELLED |
| `elo_change_type` | MATCH_WIN, MATCH_LOSS, ADJUSTMENT |
| `payment_status` | REQUIRES_PAYMENT, PROCESSING, SUCCEEDED, FAILED, REFUNDED |

---

## Triggers

| Trigger | Tabla | Evento | Función |
|---------|-------|--------|---------|
| `trg_tournament_created_assign_organizer` | tournaments | AFTER INSERT | Asigna creador como organizer |
| `trg_matches_conflict_resolution` | matches | BEFORE UPDATE | Protección time-tampering |
| `trg_scores_conflict_resolution` | scores | BEFORE UPDATE | Protección time-tampering |
| `trg_match_completion` | matches | AFTER UPDATE | Calcula ELO |
| `trg_advance_bracket` | matches | AFTER UPDATE | Avanza bracket |

---

*Ver [ER Diagram](../architecture/ER_DIAGRAM) para relaciones visuales*
