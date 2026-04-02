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

*Previous entries: See above*
