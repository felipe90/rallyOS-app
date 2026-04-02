# Proposal: Third Place Match (On-Demand)

## Intent

Agregar la opción de jugar el partido por el 3er y 4to lugar bajo demanda. El organizador puede preguntar a los perdedores de las semis si quieren jugar el third place, y si ambos aceptan, se crea el match automáticamente.

## Scope

### In Scope
- Agregar columnas `third_place_pending` y `third_place_accepted` en tabla `matches`
- Crear función RPC `offer_third_place(match_id)` para iniciar la oferta
- Crear función RPC `accept_third_place(match_id, accepted)` para que players acepten/rechacen
- Crear función RPC `create_third_place_match(semi_match_a_id, semi_match_b_id)` que crea el match
- Actualizar bracket advancement para manejar third place

### Out of Scope
- UI de confirmación (se hace después en mobile app)
- Notificaciones push
- Third place para formatos diferentes a single-elimination (round robin, double elim)

## Approach

1. **Schema**: Agregar flags en tabla `matches`
2. **RPCs**: Funciones para offer/accept/create third place
3. **Trigger**: Actualizar `advance_bracket_winner()` para detectar cuando ambas semisTerminan y hay third place pending

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000036_add_third_place_flags.sql` | New | Schema flags |
| `supabase/migrations/00000000000037_add_third_place_rpcs.sql` | New | RPCs |
| `supabase/migrations/00000000000038_update_bracket_third_place.sql` | New | Trigger update |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Race condition si ambos aceptan casi simultáneamente | Low | Usar transacción atómica |
| Players que ya se fueron del tournament | Low | Verificar que están checked-in |

## Rollback Plan

Reversión de migrations en orden inverso.

## Success Criteria

- [ ] Columns `third_place_pending` y `third_place_accepted` existen en matches
- [ ] RPC `offer_third_place` crea la oferta
- [ ] RPC `accept_third_place` registra aceptación
- [ ] RPC `create_third_place_match` crea match con perdedores deambas semis
- [ ] Flujo E2E test: semi termina → offer → accept×2 → third place creado
