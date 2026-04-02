# Migration Index

Estado actualizado: 2026-04-02

## Resumen

```yaml
Total: 35
Completadas: 35
Pendientes: 0
```

---

## Migration Map

```yaml
0000: init_schema.sql                   - Core Schema
19: architectural_overhaul.sql        - Normalization & Identity
20: real_elo_engine.sql               - PRO ELO Engine
21: deterministic_brackets.sql        - Deterministic Logic
22: engagement_tables.sql             - Gamification
23: pin_logic.sql                     - Self-Refereeing
24: localization_schema.sql           - Global Ready
25: seed_countries.sql                 - L10N Data
26-30: Staff & Player-As-Referee      - Staff Management System
31: add_sport_scoring_config.sql      - Sport-Specific Scoring Config
32: add_score_validation_trigger.sql   - Score Validation Trigger (+ fix 0-0 inicial)
33: add_scorer_logic_functions.sql      - Game/Set Winner Functions (+ fix nombres de campos)
34: update_bracket_advancement_sport_rules.sql - Sport Rules in Bracket (+ fix sets_json)
35: seed_sports_with_scoring_config.sql - 4 Sports with Full Config
36: add_third_place_flags.sql         - Third Place Match flags
37: add_third_place_rpcs.sql          - Third Place Match RPCs (offer/accept/create)
```

---

## Detalle por Migration

### 19 - architectural_overhaul.sql
**Feature**: Architecture Audit / Overhaul
**SDD**: `architectural-overhaul`

**Contenido**:
- Normalización de `match_sets` (Relacional).
- Unificación de Identidad (Persons 1:1 Auth User).
- Slots Determinísticos (`winner_to_slot`).

---

### 20/21 - ELO & Bracket Logic
**Feature**: Core Tournament Logic
**SDD**: `real-elo-engine`, `deterministic-brackets`

**Contenido**:
- `process_match_completion()`: REAL ELO comparison based on sets.
- `advance_bracket_winner()`: Deterministic slot assignment.

---

### 22/23 - Engagement & Integrity
**Feature**: Gamification & Self-Refereeing
**SDD**: `mvp-gamification-and-refereeing`

**Contenido**:
- Tablas: `achievements`, `player_achievements`.
- Enums: `athlete_rank`.
- Trigger: `trg_generate_match_pin` (4-digit security code).

---

### 24/25 - Localization
**Feature**: Global Readiness (L10N)
**SDD**: `localization`

**Contenido**:
- Tabla: `countries` (ISO, Flag, Currency).
- Links: `persons.nationality`, `clubs.country`, `tournaments.country`.
- Seed: Colombia, Argentina, México, España, USA, Brasil, Chile, Perú.

---

## Pendientes de Implementación

```yaml
Double Elimination:   Prioridad: Baja,  Complejidad: Alta
Round Robin:         Prioridad: Baja,  Complejidad: Alta
Real-time subs:      Prioridad: Media, Complejidad: Media
```

---

## Detalle: Migraciones 31-35 (Sport-Specific Scoring)

### 31 - add_sport_scoring_config.sql
**Feature**: Sport-Specific Scoring Configuration
**SDD**: `sport-scoring-rules`

**Contenido**:
- Columna `scoring_config` JSONB en tabla `sports`
- Valores por defecto para sport genérico
- RLS para lectura por usuarios autenticados

---

### 32 - add_score_validation_trigger.sql
**Feature**: Score Validation Trigger
**SDD**: `sport-scoring-rules`

**Contenido**:
- Función `validate_score()` con lógica de win-by-2
- Trigger `trg_validate_score` en tabla scores
- Manejo de golden point y deuce

---

### 33 - add_scorer_logic_functions.sql
**Feature**: Game/Set Winner Calculation Functions
**SDD**: `sport-scoring-rules`

**Contenido**:
- `is_tiebreak()`: Detecta situación de tiebreak
- `calculate_game_winner()`: Calcula ganador de game
- `calculate_set_winner()`: Calcula ganador de set

---

### 34 - update_bracket_advancement_sport_rules.sql
**Feature**: Sport Rules in Bracket Advancement
**SDD**: `sport-scoring-rules`

**Contenido**:
- Actualización de `advance_bracket_winner()` para usar sport rules
- Fallback a lógica legacy si scoring_config no disponible

---

### 35 - seed_sports_with_scoring_config.sql
**Feature**: Seed 4 Sports with Complete Config
**SDD**: `sport-scoring-rules`

**Contenido**:
- Tennis: 15-30-40, tiebreak 7 @ 6-6
- Pickleball: 11 points, rally scoring
- Table Tennis: 11 points, deuce @ 10-10
- Padel: 15-30-40, tiebreak @ 6-6, golden point

---

---

## Comandos Útiles

```bash
# Ver todas las migraciones aplicadas
psql ... -c "SELECT * FROM supabase_migrations.schema_migrations ORDER BY version;"

# Reset completo (borra todo y recrea)
supabase db reset

# Ver triggers
psql ... -c "SELECT tgname, tablename FROM pg_trigger WHERE tgname NOT LIKE 'pg_%';"

# Ver RLS policies
psql ... -c "SELECT tablename, policyname, cmd FROM pg_policies;"
```

---

## ADR Reference

```yaml
ELO como ledger:          adr/001-elo-ledger.md
Bracket como linked list: adr/002-bracket-linked-list.md
RLS con SECURITY DEFINER: adr/003-rls-security.md
```
