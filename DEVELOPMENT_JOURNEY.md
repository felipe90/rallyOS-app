# Development Journey - RallyOS

*Last updated: April 2, 2026*

## Day 5b: Sport-Agnostic Refactor (April 2, 2026)

### Problem Identified

**CRÍTICO**: La implementación inicial de Round Robin Groups tenía asunciones específicas de Table Tennis hardcodeadas:

1. **"El perdedor arbitra al ganador"** — ES ESPECÍFICO de TT
2. **Intra-group referee** — ES ESPECÍFICO de TT amateur
3. **Grupos de 3-5** — Puede variar por deporte

**Esto contradice el pilar fundamental de RallyOS: "sport-agnostic by design"**

### Investigación Realizada

| Deporte | Grupos? | KO? | Referees | "Perdedor arbitra"? |
|---------|---------|-----|----------|---------------------|
| Table Tennis | ✅ 3-5 | ✅ | Compañeros grupo | ✅ SÍ |
| Padel Americano | ❌ NO | ❌ NO | Ninguno | ❌ NO |
| Padel Mexicano | ✅ 3-4 | ✅ | Rotan | ⚠️ A veces |
| Tennis | ⚠️ Opcional | ✅ | Umpires pro | ❌ NO |
| Badminton | ✅ 4-6 | ✅ | Umpires pro | ❌ NO |

### Solution: Sport-Agnostic Configuration

**Nueva spec creada**: `spec-dom-04-tournament-format-config.md`

```json
{
  "tournament_format": {
    "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
    "referee_mode": "INTRA_GROUP",
    "loser_referees_winner": true,
    "group_size": { "min": 3, "max": 5 }
  }
}
```

**Config por deporte**:
- **TT**: `referee_mode=INTRA_GROUP`, `loser_referees_winner=true`
- **Padel Americano**: `structure=AMERICANO`, `referee_mode=NONE`
- **Tennis**: `structure=KNOCKOUT_ONLY`, `referee_mode=ORGANIZER`
- **Badminton**: `referee_mode=EXTERNAL`, `loser_referees_winner=false`

### Specs Actualizadas

```
specs/domain/
├── spec-dom-01-entities.md       # Ahora con notas de sport-agnosticidad
├── spec-dom-02-aggregates.md     # Reglas de referee condicionales
├── spec-dom-03-business-rules.md # Configurable por sport
└── spec-dom-04-tournament-format-config.md  # NUEVA: Config completa
```

### Bugs Fixed (Sport-Agnostic Audit)

| Problema | Corrección |
|----------|------------|
| `max_members := 5` hardcoded | Leer de `scoring_config->tournament_format->group_size->max` |
| Trigger intra-group no verificaba `referee_mode` | Ahora verifica antes de aplicar regla |
| `loser_referees_winner` no se verificaba | Trigger lee de config |
| Nombre `trg_validate_score_tt_rules` | Renombrado a `fn_validate_score_rules` |
| Mensaje "Table Tennis" en trigger | Mensaje genérico |

### Implementation Pattern

```
sports.scoring_config (fuente de verdad)
         │
         ▼
triggers leen configuración
         │
         ▼
Aplican reglas condicionalmente
    │
    ├── referee_mode = 'INTRA_GROUP' → validar mismo grupo
    ├── loser_referees_winner = true → trackear perdedor
    └── group_size.max = 5 → validar límite
```

### Lessons Learned

> **Pilar fundamental de RallyOS**: "Sport-Agnostic by Design"
> 
> Nunca hardcodear asunciones de un deporte específico. Todo debe ser configurable.

---

## Day 5: Round Robin Groups & Loser-As-Referee Flow (April 2, 2026)

### Problem Identified

RallyOS necesitaba soportar el flujo real de torneos amateur de Table Tennis:
1. **Grupos Round Robin** (3-5 jugadores por grupo)
2. **Arbitraje intra-grupo** (solo compañeros del mismo grupo pueden arbitrar)
3. **"El perdedor arbitra al ganador"** (regla especial)
4. **Transición a llaves KO** post-round-robin

### Solution Designed

Siguiendo el flujo Domain → DB → Arquitectura:

#### Phase 1: Domain Model (Specs)
```
specs/domain/
├── spec-dom-01-entities.md       # Entidades (Torneo, Grupo, Partido, etc.)
├── spec-dom-02-aggregates.md      # Aggregates e invariantes
└── spec-dom-03-business-rules.md  # Reglas de negocio (3-5 jugadores, seeding, etc.)
```

#### Phase 2: Database Schema
```
supabase/migrations/
├── 00000000000038_round_robin_tables.sql  # Tablas nuevas
├── 00000000000039_rr_triggers.sql          # Triggers de validación
└── 00000000000040_rr_rpcs.sql             # RPCs de operaciones
```

**Nuevas tablas:**
- `round_robin_groups` — Grupos de 3-5 jugadores
- `group_members` — Miembros con seed y status
- `knockout_brackets` — Llave de KO
- `bracket_slots` — Posiciones en la llave

**Nuevos enums:**
- `group_status`: PENDING, IN_PROGRESS, COMPLETED
- `member_status`: ACTIVE, WALKED_OVER, DISQUALIFIED
- `match_phase`: ROUND_ROBIN, KNOCKOUT, BRONZE, FINAL
- `assignment_type`: AUTOMATIC, MANUAL, LOSER_ASSIGNED

**Nuevos triggers:**
| Trigger | Propósito |
|---------|-----------|
| trg_validate_group_member_count | Max 5 miembros |
| trg_unique_person_per_tournament | Un grupo por persona |
| trg_unique_seed_per_group | Seeds únicos |
| trg_update_group_status | Auto-completar grupo |
| trg_validate_intra_group_referee | Referee del mismo grupo |
| trg_track_loser_for_referee | Guardar perdedor para próximo partido |

**Nuevas RPCs:**
| RPC | Propósito |
|-----|-----------|
| create_round_robin_group() | Crear grupo + matches |
| generate_round_robin_matches() | Schedule circular |
| suggest_intra_group_referee() | Sugerir referee |
| assign_loser_as_referee() | "El perdedor arbitra" |
| calculate_group_standings() | Clasificación |
| generate_bracket_from_groups() | Generar KO |

#### Phase 3: Architecture (Specs)
```
specs/architecture/
├── spec-arch-01-tournament-state-machine.md  # Estados del torneo
├── spec-arch-02-group-management.md           # UI de grupos
├── spec-arch-03-referee-flow.md               # Flujo de arbitraje
└── spec-arch-04-score-entry.md                # Entrada manual de scores
```

### Documentación Actualizada

- `webdocs/database/schema.md` → Nuevas tablas, enums, triggers, RPCs
- `webdocs/architecture/ER_DIAGRAM.md` → Nuevas relaciones y flows

---

## Day 5: Sport-Specific Scoring Rules Engine (April 2, 2026)

### Problem Identified

RallyOS声称是sport-agnostic (deporte agnóstico), pero la tabla `sports` solo tenía:
- `scoring_system` (POINTS/GAMES)
- `default_points_per_set`
- `default_best_of_sets`

**Gap crítico**: No había forma de:
1. Validar si un score es válido para el deporte
2. Aplicar tie-breaks específicos
3. Manejar golden point (Padel) o deuce (TT)

### Solution Designed

Extender `sports` con JSONB `scoring_config` + funciones de validación:

#### Scoring por Deporte Investigado

| Sport | Pts/Game | Win by 2 | Tiebreak | Golden Point |
|-------|----------|----------|----------|--------------|
| Tennis | 4 (15-30-40) | ✅ | 7 @ 6-6 | ❌ |
| Padel | 4 (15-30-40) | ✅ | 7 @ 6-6 | ✅ @ 40-40 |
| Pickleball | 11 | ✅ | ❌ | N/A |
| Table Tennis | 11 | ✅ | ❌ | N/A (deuce @ 10-10) |

#### Migration Files Created

```
supabase/migrations/
├── 00000000000031_add_sport_scoring_config.sql    # Columna JSONB
├── 00000000000032_add_score_validation_trigger.sql # validate_score()
├── 00000000000033_add_scorer_logic_functions.sql    # calculate_game/set_winner()
├── 00000000000034_update_bracket_advancement_sport_rules.sql
└── 00000000000035_seed_sports_with_scoring_config.sql
```

### Functions Implemented

| Function | Descripción |
|----------|-------------|
| `validate_score(match_id, points_a, points_b)` | Valida win-by-2, lanza excepción si inválido |
| `calculate_game_winner(score_a, score_b, config)` | Retorna 'A'/'B'/NULL |
| `calculate_set_winner(sets_json, config)` | Maneja tiebreak, super tiebreak |
| `is_tiebreak(game_a, game_b, config)` | Boolean helper |

### Tests Results

| Test | Resultado |
|------|-----------|
| RLS scores | ✅ PASS |
| ELO History | ✅ PASS |
| PII leakage | ✅ PASS |
| Time-tampering | ✅ PASS (fix en test query) |
| Staff self-elevation | ✅ PASS |
| Entry status RLS | ✅ PASS |

### Custom Validation Tests (E2E)

| Score | Sport | Expected | Result |
|-------|-------|----------|--------|
| 0-0 | Padel | Valid (inicio) | ✅ PASS |
| 4-2 | Padel | Valid | ✅ PASS |
| 4-3 | Padel | Invalid | ✅ REJECTED |
| 11-9 | Pickleball | Valid | ✅ PASS |
| 12-10 | Golden Point | Valid | ✅ PASS |

### Bugs Fixed During Testing

1. **0-0 score rejection**: Trigger rechazaba scores iniciales 0-0
   - Fix: Agregué excepción para permitir 0-0 como estado inicial
   - Migration: 00000000000032_add_score_validation_trigger.sql

2. **sets_json column missing**: Bracket advancement fallaba porque esperaba columna que no existe
   - Fix: Cambié a usar points_a/points_b directamente
   - Migration: 00000000000034_update_bracket_advancement_sport_rules.sql

3. **Inconsistent field names**: calculate_game_winner esperaba nombres distintos a los del scoring_config
   - Fix: COALESCE acepta ambos formatos (points_to_win_game vs points_per_set)
   - Migration: 00000000000033_add_scorer_logic_functions.sql

### E2E Flow Completed

```
Bracket generated → Players assigned → Score 4-2 → Match FINISHED → Felipe advances to Final ✅
```

### Documentation Updated

- `webdocs/database/schema.md` → scoring_config + funciones de scoring
- `webdocs/database/MIGRATION_INDEX.md` → Migrations 31-35
- `webdocs/architecture/ER_DIAGRAM.md` → Updated

---

## Day 5: Implementation & Testing (April 2, 2026)

### Objective: Implementar Staff & Player-As-Referee System

#### Migraciones Creadas

| # | Archivo | Descripción |
|---|---------|-------------|
| 26 | `staff_enhanced.sql` | ENUM staff_status, columnas en tournament_staff |
| 27 | `referee_pool.sql` | referee_volunteers, referee_assignments, vista available_referees |
| 28 | `staff_rpcs.sql` | 9 RPCs: assign_staff, invite_staff, accept/reject, toggle_volunteer, generate_suggestions, etc. |
| 29 | `staff_rls_update.sql` | RLS policies actualizadas |

#### Seed Actualizado

Integrado en `supabase/seed.sql`:
- 11 usuarios de test (auth.users)
- 23 personas (11 con auth + 12 shadow profiles)
- 2 torneos (v1 LIVE con matches, v2 DRAFT)
- 3 categorías
- 20 entries
- 5 tournament_staff (1 organizer, 2 referees pendientes)

#### Fixes Aplicados

1. **Índices en vistas**: Removido índices en `available_referees` (no soportado)
2. **Club owner_user_id**: FK a auth.users requiere usuario existente
3. **Tournament club_id**: Removido del seed (columna no existe en schema)
4. **Auth.users FK**: Creados usuarios de test antes de persons
5. **Seed order**: Integración directa en seed.sql (migraciones se ejecutan antes)
6. **Sports dependency**: Uso de subqueries para sports no existentes aún
7. **Score validation**: Corregido seed original con scores inválidos

#### Documentación Actualizada

- `webdocs/database/schema.md`: Nuevas tablas, enums, triggers, RPCs
- `webdocs/architecture/ER_DIAGRAM.md`: Nuevas relaciones
- `webdocs/architecture/ARCHITECTURE_DIAGRAMS.md`: Nuevos flows

#### Estado Final

```
✅ Database Reset: SUCCESS
✅ Sports: 4
✅ Users: 11
✅ Persons: 23
✅ Tournaments: 2
✅ Categories: 3
✅ Entries: 20
✅ Staff: 5 (1 organizer, 2 pending referees)
```

---

## Day 6: Final Evaluation & Fixes (April 2, 2026)

### Evaluación Final - Bugs Encontrados

Durante la auditoría crítica del sistema, se encontraron múltiples problemas que fueron corregidos:

#### 1. Enums No Idempotentes
**Problema**: Las migraciones creaban enums sin verificar si ya existían, causando errores en reset.

**Fix**: Usar `DO $$` blocks con `IF NOT EXISTS`:

```sql
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'group_status') THEN
        CREATE TYPE group_status AS ENUM ('PENDING', 'IN_PROGRESS', 'COMPLETED');
    END IF;
END $$;
```

#### 2. tournament_status Enum Conflict
**Problema**: La migración 38 intentaba crear `tournament_status` completo cuando ya existía en init_schema.sql.

**Fix**: Usar `ALTER TYPE ADD VALUE`:

```sql
ALTER TYPE tournament_status ADD VALUE IF NOT EXISTS 'PRE_TOURNAMENT';
ALTER TYPE tournament_status ADD VALUE IF NOT EXISTS 'SUSPENDED';
ALTER TYPE tournament_status ADD VALUE IF NOT EXISTS 'CANCELLED';
```

#### 3. Duplicate Score Validation Trigger
**Problema**: La migración 39 redefinía el trigger `trg_validate_score` que ya existía en migración 32.

**Fix**: Removido el trigger duplicado. El trigger de migración 32 ya maneja validación sport-agnostic.

#### 4. SQL Syntax Error en Duplicate Check
**Problema**: 
```sql
-- ERROR:
array_length(p_member_entry_ids, 1) != array_length(DISTINCT ARRAY(...), 1)
```

**Fix**:
```sql
array_length(p_member_entry_ids, 1) != (SELECT COUNT(DISTINCT unnest) FROM unnest(p_member_entry_ids))
```

#### 5. person_id Not Retrieved
**Problema**: `create_round_robin_group` no obtenía `person_id` de `entry_members`.

**Fix**:
```sql
INSERT INTO group_members (group_id, entry_id, person_id, seed)
SELECT 
    v_group_id,
    v_entry_id,
    (SELECT person_id FROM entry_members WHERE entry_id = v_entry_id LIMIT 1),
    v_seed;
```

#### 6. JOIN Syntax Error
**Problema**: `generate_round_robin_matches` tenía JOIN incompleto.

**Fix**:
```sql
-- CORRECTO:
SELECT te.category_id INTO v_category_id
FROM round_robin_groups rrg
JOIN group_members gm ON gm.group_id = rrg.id
JOIN tournament_entries te ON te.id = gm.entry_id
WHERE rrg.id = p_group_id
LIMIT 1;
```

#### 7. Enum Value Mismatch
**Problema**: Triggers usaban `WALKED_OVER` pero el enum es `W_O`.

**Fix**: Cambiado a `W_O` en todos los triggers.

### Database Reset Test Results

```
✅ round_robin_groups: 1 table
✅ group_members: 1 table  
✅ knockout_brackets: 1 table
✅ bracket_slots: 1 table

✅ Enums: group_status, member_status, bracket_status, match_phase, assignment_type
✅ Triggers: 7 triggers created
✅ Functions: 11 RR functions created

✅ create_round_robin_group() - TESTED SUCCESS
   └── Grupo "A" creado con 3 miembros
   └── 3 matches generados (n*(n-1)/2 = 3)
   └── phase = ROUND_ROBIN
   └── round_number = 1, 1, 2
```

### Commits del Día

```
3a4455d fix: get person_id from entry_members in create_round_robin_group
648f43a fix: SQL syntax error in generate_round_robin_matches category_id query
5e7d97b fix: use W_O instead of WALKED_OVER (correct enum value)
d400dca fix: SQL syntax error in create_round_robin_group duplicate check
a08830e fix: make migrations idempotent, fix enum conflicts
277a701 fix: correct Mermaid ERD syntax
6277c44 fix: remove duplicate next_match_id in MATCHES
c477266 fix: make all triggers read sport config
b5f7ac9 feat: implement sport-agnostic round robin
```

---

## Day 6b: Add recorded_by to Scores (April 2, 2026)

### Fix: scores.recorded_by

**Problema identificado durante walkthrough:**
- La spec indicaba que `scores` debía tener `recorded_by` para saber quién registró el score
- El flujo correcto: "el referee del match es quien registra los puntos"

**Solución:**
```sql
-- Nueva migración: 00000000000041_scores_recorded_by.sql
ALTER TABLE scores ADD COLUMN recorded_by UUID REFERENCES auth.users(id);

-- Trigger para auto-setear
CREATE OR REPLACE FUNCTION fn_set_score_recorder()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.recorded_by := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_score_recorder
BEFORE INSERT ON scores
FOR EACH ROW EXECUTE FUNCTION fn_set_score_recorder();
```

**Verificado:**
```
✅ Column created
✅ Index created
✅ Trigger created
✅ FK to auth.users
```

---

## Day 6c: E2E Testing & Seed Fix (April 2, 2026)

### Problema: Seed no funcionaba

**Errores encontrados:**
1. `gen_salt()` no existía - pgcrypto vive en schema `extensions`
2. FK de matches: Final insertada después de semis (violación)
3. Constraint `name_length` muy restrictivo (<=10 chars)

### Solución

```sql
-- Fix 1: Incluir extensions schema
SET search_path TO extensions, public;

-- Fix 2: Reordenar inserts (Final primero)
INSERT INTO matches (id, ..., round_name) VALUES ('final-id', ..., 'Final');
INSERT INTO matches (id, ..., next_match_id) VALUES ('semi1-id', ..., 'final-id');
INSERT INTO matches (id, ..., next_match_id) VALUES ('semi2-id', ..., 'final-id');

-- Fix 3: Constraint más flexible
ALTER TABLE round_robin_groups 
ADD CONSTRAINT name_length CHECK (char_length(name) BETWEEN 1 AND 50);
```

### Migration 42: RLS Policies

**Agregadas 16 policies** para tablas RR:
- round_robin_groups: 4 policies (SELECT, INSERT, UPDATE, DELETE)
- group_members: 4 policies
- knockout_brackets: 4 policies
- bracket_slots: 4 policies

### E2E Test Results

```
✅ Group created: Grupo A (4 members)
✅ Matches generated: 6 (n*(n-1)/2 = 4*3/2)
✅ RLS: All 4 tables secured
```

---

## Day 7: Security Hardening (April 3, 2026)

### Problema: Evaluación crítica reveló 3 gaps CRÍTICOS

| Tabla | Datos Expuestos | Riesgo |
|-------|-----------------|---------|
| athlete_stats | 23 rows | Cualquiera podía ver ELOs |
| payments | 4 rows | Datos de pago expuestos |
| match_sets | 8 rows | Scores expuestos |

**RPCs sin SECURITY DEFINER**: 10 funciones no podían llamarse entre sí

**elo_history vacío**: Tabla existía pero trigger no la povoaba

### Solución Implementada

#### 1. RLS en 3 Tablas Sensibles (Migration 48)

```sql
-- athlete_stats
ALTER TABLE athlete_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view athlete stats" FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "Players can update own stats" FOR UPDATE TO authenticated USING (...);

-- payments
CREATE POLICY "Users can view own payments" FOR SELECT TO authenticated USING (...);
CREATE POLICY "Payments insert blocked for users" FOR INSERT TO authenticated WITH CHECK (FALSE);
CREATE POLICY "Organizers can update payment status" FOR UPDATE TO authenticated USING (...);

-- match_sets
CREATE POLICY "Authenticated users can view match sets" FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "Match sets modified via scores trigger only" FOR INSERT TO authenticated WITH CHECK (FALSE);
```

#### 2. SECURITY DEFINER en 10 RPCs (Migration 49)

```sql
CREATE OR REPLACE FUNCTION create_round_robin_group(...)
RETURNS ...
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
BEGIN
    -- Explicit auth check
    IF NOT EXISTS (SELECT 1 FROM tournament_staff WHERE ...) THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    ...
END;
$$;
```

#### 3. Trigger para elo_history (Migration 50)

```sql
-- Columna para tracking
ALTER TABLE athlete_stats ADD COLUMN last_match_id UUID REFERENCES matches(id);

-- Trigger function
CREATE OR REPLACE FUNCTION fn_record_elo_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.current_elo != NEW.current_elo THEN
        INSERT INTO elo_history (
            person_id, sport_id, match_id,
            previous_elo, new_elo, elo_change, change_type
        ) VALUES (
            NEW.person_id, NEW.sport_id, NEW.last_match_id,
            OLD.current_elo, NEW.current_elo,
            NEW.current_elo - OLD.current_elo,
            CASE WHEN NEW.current_elo > OLD.current_elo THEN 'MATCH_WIN' ELSE 'MATCH_LOSS' END
        );
        NEW.last_match_id := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_record_elo_change
BEFORE UPDATE OF current_elo ON athlete_stats
FOR EACH ROW EXECUTE FUNCTION fn_record_elo_change();
```

### Métricas Finales

| Métrica | Antes | Después |
|---------|-------|---------|
| RLS Policies | 68 | 79 (+11) |
| RPCs con SD | 0/10 | 10/10 |
| elo_history | 0 | 1+ |
| Tablas sin RLS | 6 | 3 (low-risk) |

### Tests Pasados

```
✅ Security Tests: 18/18 PASS
✅ Integration Tests: 7/7 PASS
✅ Scoring Rules Tests: 8/8 PASS
```

---

## Estado del Sistema (Post-Security Hardening)

### ✅ LISTO PARA PRODUCCIÓN

| Área | Estado |
|------|--------|
| Features Core | ✅ Completo |
| Seguridad | ✅ Hardened |
| Testing | ✅ Suite completa |
| Documentación | ✅ Actualizada |

### Tablas con RLS (25 total)

```
✅ tournaments, categories, tournament_entries, matches, scores
✅ tournament_staff, round_robin_groups, group_members
✅ knockout_brackets, bracket_slots
✅ athlete_stats, payments, match_sets (NEW)
✅ persons, elo_history
```

### Tablas sin RLS (reference data, bajo riesgo)

```
⚠️ achievements (0 rows)
⚠️ countries (0 rows)
⚠️ player_achievements (0 rows)
```

---

*Previous entries: See above*
