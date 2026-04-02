# Proposal: Sport-Specific Scoring Rules Engine

## Intent

RallyOS声称是sport-agnostic，但实际上缺少sport-specific scoring rules。La tabla `sports` solo tiene `scoring_system` (POINTS/GAMES), `default_points_per_set`, y `default_best_of_sets`. No hay forma de validar scores ni aplicar tie-breaks específicos por deporte.

## Scope

### In Scope
- Extender tabla `sports` con columnas de reglas
- Agregar validación en score entry (RLS + trigger)
- Agregar lógica de tie-break en bracket advancement
- Soporte para los 4 deportes iniciales: Tennis, Pickleball, Table Tennis, Padel

### Out of Scope
- UI de configuración de reglas (deferido)
- Deportes con reglas complejas (badminton, squash)
- Match simulation / predictions

## Approach

Extender `sports` con JSONB config para flexibilidad:
- `scoring_config`: JSONB con reglas específicas
- Trigger `validate_score()` que valida contra reglas del sport del match
- Función `calculate_set_winner()` con lógica de tie-break

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/0000000000000X_add_sport_rules.sql` | New | Schema + seed data |
| `supabase/migrations/0000000000000X_add_score_validation.sql` | New | RLS + triggers |
| `supabase/migrations/0000000000000X_add_tiebreak_logic.sql` | New | Bracket logic |
| `openspec/changes/sport-scoring-rules/` | New | Specs |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| JSONB performance | Low | Index on sport_id |
| Breaking existing scores | Med | Solo aplica a nuevos matches |

## Rollback Plan

Reversión de migrations en orden inverso.

## Success Criteria

- [ ] Tabla `sports` tiene `scoring_config` con todas las reglas
- [ ] Score entry rechaza scores inválidos (trigger)
- [ ] Tie-break funciona para Tennis (7 puntos)
- [ ] Tests de seguridad pasan
