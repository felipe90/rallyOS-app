# Development Journey - RallyOS

*Last updated: April 2, 2026*

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

*Previous entries: See DEVELOPMENT_JOURNEY.md (archived)*
