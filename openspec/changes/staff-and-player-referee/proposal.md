# Proposal: Staff & Player-As-Referee System

## Intent

Implementar un sistema completo de gestión de staff para torneos que soporte: (1) asignación automática/manual de referees, (2) que jugadores checked-in puedan arbitrar matches donde no juegan, y (3) confirmación manual de assignments por el organizer.

## Scope

### In Scope
- SPEC-010: Tournament Staff Management (3 roles, 2 modos)
- SPEC-011: Player-As-Referee Pool
- Vista `available_referees(match_id)`
- RLS actualizada para todos los flujos
- 8 Casos de Uso (CU-11 a CU-18)
- Seed actualizado con 16 usuarios dummy

### Out of Scope
- Sistema de notificaciones (invitaciones por email)
- Gamification de referees (badges/rankings)
- Estadísticas detalladas de arbitraje

## Approach

1. **Modelo híbrido de staff**: Mantener `tournament_staff` con 3 roles + tabla `referee_volunteers` para tracking de disponibilidad
2. **Vista materialized**: `available_referees` que filtra checked-in + no-playing
3. **RPCs seguras**: `assign_referee()`, `accept_invitation()`, `toggle_volunteer()`
4. **Sistema de sugerencias**: Round-robin automático con override manual

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/` | New | 3 nuevas migraciones |
| `tournament_staff` | Modified | Agregar `status` enum y `invited_by` |
| `matches` | Modified | RLS actualizada para PLAYER_REFEREE |
| `seed.sql` | Modified | 16 usuarios dummy + staff |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Race condition en assignment | Med | Usar `SELECT FOR UPDATE` en RPC |
| Jugador se asigna a sí mismo | Low | Filtro en vista `available_referees` |
| Conflicto de permisos | Low | RLS estratificada por rol |

## Rollback Plan

1. Revertir migraciones con `supabase db reset`
2. Restaurar seed.sql anterior
3. Tests de regresión con dataset existente

## Success Criteria

- [ ] 3 roles de staff funcionales (ORGANIZER, EXTERNAL_REFEREE, PLAYER_REFEREE)
- [ ] Vista `available_referees` retorna jugadores checked-in excluyendo participantes del match
- [ ] Sistema de invitación con accept/reject funciona
- [ ] Asignación automática sugiere referees por round-robin
- [ ] Organizer puede confirmar/reasignar cualquier match
- [ ] Seed con 16 usuarios y 2 categorías ejecuta flujo completo
