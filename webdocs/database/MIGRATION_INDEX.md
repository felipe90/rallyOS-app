# Migration Index

**Estado actualizado**: 2026-04-02

---

## Resumen

```yaml
Total migrations: 51
Completadas: 51
Pendientes: 0
```

---

## Migration Map (38-51)

```yaml
38: round_robin_tables.sql         - Round Robin Groups schema
39: rr_triggers.sql                 - Round Robin triggers
40: rr_rpcs.sql                    - Round Robin RPCs
41: scores_recorded_by.sql          - Audit trail for scores
42: rr_rls_policies.sql            - RLS for RR tables
43: fix_rr_name_constraint.sql      - Name constraint 1-50 chars
44: add_elo_history.sql            - ELO history table
45: seed_v2.sql                    - Copa Padel v2 seed
46: sport_scoring_config.sql        - Sport-specific scoring
47: add_score_validation.sql        - validate_score trigger
48: rls_sensitive_tables.sql        - RLS on athlete_stats, payments, match_sets
49: rpc_security_definer.sql        - SECURITY DEFINER on 10 RPCs
50: elo_history_trigger.sql        - Auto-populate elo_history, RLS policies
51: post_match_feedback.sql        - Achievements, share cards, leaderboard
```

---

## Migration Map Completo (1-51)

```yaml
0001: foundation.sql                 - Core schema (squashed from 40)
0038-040: Round Robin Groups         - RR tables, triggers, RPCs
0041-043: Score Audit & RLS Fix    - recorded_by, RR policies, constraints
0044-047: Sport Scoring Engine      - ELO history, scoring config, validation
0048-050: Security Hardening        - RLS, SECURITY DEFINER, triggers
0051: Post-Match Feedback          - Achievements, share cards, leaderboard
```

---

## Detalle: Migraciones 38-43 (Round Robin)

### 38 - round_robin_tables.sql
**Feature**: Round Robin Groups Schema
**SDD**: `table-tennis-flow`

**Contenido**:
- Tabla `round_robin_groups`: Grupos RR (name, advancement_count, status)
- Tabla `group_members`: Miembros (entry_id, seed, status, check_in_at)
- Enum `group_status`: PENDING, IN_PROGRESS, COMPLETED
- Enum `member_status`: ACTIVE, WALKED_OVER, DISQUALIFIED
- Enum `bracket_status`: PENDING, IN_PROGRESS, COMPLETED
- Enum `match_phase`: ROUND_ROBIN, KNOCKOUT, BRONZE, FINAL
- FK constraints y índices

---

### 39 - rr_triggers.sql
**Feature**: Round Robin Triggers
**SDD**: `table-tennis-flow`

**Contenido**:
- `trg_set_group_in_progress`: Al primer match → IN_PROGRESS
- `trg_set_group_completed`: Al completar todos → COMPLETED
- `trg_assign_intra_group_referee`: Asigna referee intra-grupo
- `trg_track_loser_for_referee`: Trackea perdedor para arbitraje
- `trg_update_elo_from_match`: Actualiza ELO al finish

---

### 40 - rr_rpcs.sql
**Feature**: Round Robin RPCs
**SDD**: `table-tennis-flow`

**Contenido**:
- `create_round_robin_group()`: Crea grupo + members + matches
- `generate_round_robin_matches()`: Genera matches con algoritmo RR
- `advance_round_robin_winner()`: Mueve ganador a bracket
- `get_group_standings()`: Calcula standings (W-L, points)
- `get_intra_group_referees()`: Lista referees disponibles

---

### 41 - scores_recorded_by.sql
**Feature**: Score Audit Trail
**SDD**: `table-tennis-flow`

**Contenido**:
- Columna `recorded_by` UUID en tabla `scores`
- FK a `auth.users`
- Trigger `trg_set_score_recorder`: Auto-set auth.uid()

---

### 42 - rr_rls_policies.sql
**Feature**: RLS for Round Robin Tables
**SDD**: `table-tennis-flow`

**Contenido**:
- 4 tablas: round_robin_groups, group_members, knockout_brackets, bracket_slots
- 16 policies: SELECT, INSERT, UPDATE, DELETE por tabla
- Todas restringuen a ORGANIZER role

---

### 43 - fix_rr_name_constraint.sql
**Feature**: Fix Name Constraint
**SDD**: `table-tennis-flow`

**Contenido**:
- Constraint: `char_length(name) BETWEEN 1 AND 50`
- Permite nombres descriptivos: "Grupo A", "Primera Ronda"

---

## Detalle: Migraciones 44-47 (Sport Scoring)

### 44 - add_elo_history.sql
**Feature**: ELO History Table
**SDD**: `sport-scoring-rules`

**Contenido**:
- Tabla `elo_history`: Audit trail de cambios de ELO
- Enum `elo_change_type`: MATCH_WIN, MATCH_LOSS, ADJUSTMENT, TOURNAMENT_BONUS
- Columnas: person_id, sport_id, match_id, previous_elo, new_elo, elo_change
- Índices: (person_id, sport_id), (match_id)

---

### 45 - seed_v2.sql
**Feature**: Copa Padel Medellín 2026 v2
**SDD**: `staff-and-player-referee`

**Contenido**:
- 1 Organizer, 2 External Referees, 16 Players
- 8 con auth + 8 shadow profiles
- 2 categorías: Primera (ELO 900-1200), Segunda (ELO 600-899)
- 16 entries, 2 tournaments (v1 + v2)

---

### 46 - sport_scoring_config.sql
**Feature**: Sport-Specific Scoring Configuration
**SDD**: `sport-scoring-rules`

**Contenido**:
- Columna `scoring_config` JSONB en tabla `sports`
- Seed: Tennis, Pickleball, Table Tennis, Padel
- Full config: tournament_format, scoring, game_scoring

---

### 47 - add_score_validation.sql
**Feature**: Score Validation Trigger
**SDD**: `sport-scoring-rules`

**Contenido**:
- Función `validate_score()`: Valida scores según sport config
- Trigger `trg_validate_score`: BEFORE INSERT/UPDATE on scores
- Manejo de: Tennis 15-30-40, Standard, Deuce modes

---

## Detalle: Migraciones 48-50 (Security Hardening)

### 48 - rls_sensitive_tables.sql
**Feature**: RLS on Sensitive Tables
**SDD**: `security-hardening`

**Contenido**:
- `athlete_stats`: SELECT público, UPDATE propio
- `payments`: SELECT propio/org, INSERT bloqueado, UPDATE org
- `match_sets`: SELECT público, INSERT/UPDATE/DELETE bloqueado

---

### 49 - rpc_security_definer.sql
**Feature**: SECURITY DEFINER on RPCs
**SDD**: `security-hardening`

**Contenido**:
- 10 RPCs ahora tienen SECURITY DEFINER:
  - create_round_robin_group, generate_round_robin_matches
  - offer_third_place, accept_third_place, create_third_place_match
  - get_match_loser, assign_staff, invite_staff
  - generate_referee_suggestions, validate_score
- SET search_path TO extensions, public en todos
- Auth checks preservados

---

### 50 - elo_history_trigger.sql
**Feature**: Auto-populate ELO History
**SDD**: `security-hardening`

**Contenido**:
- Columna `last_match_id` en `athlete_stats`
- Trigger `trg_record_elo_change`: BEFORE UPDATE on current_elo
- Función `record_elo_adjustment()`: Para ajustes manuales
- RLS policies: usuarios ven su historia, orgs ven la del torneo

---

## Comandos Útiles

```bash
# Ver todas las migraciones aplicadas
psql ... -c "SELECT * FROM pg_catalog.pg_extension WHERE extname = 'supabase';"

# Ver todas las tablas
psql ... -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"

# Ver triggers
psql ... -c "SELECT tgname, relname FROM pg_trigger WHERE tgname NOT LIKE 'pg_%';"

# Ver RLS policies
psql ... -c "SELECT tablename, policyname, cmd FROM pg_policies;"

# Ver SECURITY DEFINER functions
psql ... -c "SELECT proname FROM pg_proc WHERE prosecdef = true;"

# Ver elo_history records
psql ... -c "SELECT * FROM elo_history ORDER BY created_at DESC LIMIT 10;"
```

---

## Specs Reference

```yaml
Specs completas en: openspec/changes/
├── table-tennis-flow/     # Round Robin + Loser-As-Referee
├── staff-and-player-referee/ # Staff + Player-As-Referee
├── sport-scoring-rules/   # Sport-Specific Scoring Engine
├── security-hardening/    # Security Hardening (RLS, SECURITY DEFINER)
└── third-place-match/     # Third Place Match Flow
```

---

## Tests

```bash
# Security tests
psql ... -f supabase/tests/security_tests.sql

# Integration tests
psql ... -f supabase/tests/integration_tests.sql

# Scoring rules tests
psql ... -f supabase/tests/scoring_rules_tests.sql
```
