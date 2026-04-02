# CU-18: Flujo E2E - Copa Pádel Medellín 2026 v2

## Escenario de Prueba
Validar el flujo completo del sistema de staff y player-as-referee con 16 jugadores, 2 categorías, y gestión de referees.

## Dataset Inicial

| Tipo | Cantidad | Notas |
|------|----------|-------|
| Organizador | 1 | user_id + persona, tiene auth |
| External Referees | 2 | user_id + persona, tienen auth |
| Jugadores | 16 | 8 con auth + 8 shadow profiles |
| Categorías | 2 | "Primera" (ELO 900-1200), "Segunda" (ELO 600-899) |
| Matches | 14 | 6 por categoría (semifinales + final), 2 bronca-cerveza |

## Precondiciones de Setup

1. Sport "Padel" existe en tabla `sports`
2. 1 auth.user con person linked (Organizador)
3. 2 auth.user con person linked (Referees externos)
4. 16 persons creadas:
   - 8 con user_id linked (jugadores reales)
   - 8 sin user_id (shadow profiles para probar ambos casos)
5. 16 athlete_stats creadas con ELOs variados:
   - 8 en rango 900-1200 (para Primera)
   - 8 en rango 600-899 (para Segunda)

## Flujo Principal E2E

### Fase 1: Setup del Torneo

```
1.1 Organizador crea torneo "Copa Pádel Medellín 2026"
    → Sistema crea registro + tournament_staff (ORGANIZER, ACTIVE)
    → Status: DRAFT

1.2 Organizador invita a 2 referees externos
    → Se crean registros PENDING en tournament_staff
    → (En test, auto-aceptamos)

1.3 Referees aceptan invitaciones
    → Status cambia a ACTIVE
    → Ahora son EXTERNAL_REFEREE activos

1.4 Organizador crea categoría "Primera" (ELO 900-1200)
    → 8 jugadores se registran
    → Status: REGISTRATION

1.5 Organizador crea categoría "Segunda" (ELO 600-899)
    → 8 jugadores se registran
    → Status: REGISTRATION
```

### Fase 2: Check-In y Voluntarios

```
2.1 Torneos pasan a CHECK_IN
    → 16 jugadores completan check-in
    → checked_in_at actualizado

2.2 Jugadores con auth se ofrecen como voluntarios
    → CU-13: toggle_referee_volunteer(true)
    → Se crean/actualizan referee_volunteers + PLAYER_REFEREE en tournament_staff
    → Los 8 shadow profiles NO pueden ser voluntarios (sin user_id)

2.3 Verificar pool de referees disponibles
    → Query available_referees para matches de Primera
    → Retorna: 2 EXTERNAL_REFEREES + 8 PLAYER_REFEREES (auth) - 2 jugando
    → Total disponible esperado: 8 por match
```

### Fase 3: Generación de Brackets con Referees

```
3.1 Organizador genera brackets para "Primera"
    → Sistema crea 6 matches (semifinales + bronca-cerveza + final)
    → Sistema ejecuta generate_referee_suggestions()

3.2 Sistema sugiere referees automáticamente
    → Round-robin reparte 8 refs entre 6 matches
    → 2 refs quedan disponibles para reasignación

3.3 Organizador revisa y confirma suggestions
    → CU-14: Confirmar Todos

3.4 Repetir para "Segunda"
    → 6 matches con mismos referees disponibles
```

### Fase 4: Desarrollo del Torneo

```
4.1 Matches en status CALLING
    → Sistema notifica a referees asignados

4.2 Referee de Match #1 ingresa score (set por set)
    → CU-05: process_score_update()
    → Valida que es referee_id del match

4.3 Match #1 finalizado
    → ELO actualizado para ambos jugadores
    → Ganador avanza al siguiente match
    → Referee liberado para otros matches

4.4 Organizador reasigna referee en Match #5
    → CU-15: Override de sugerencia
    → Reason: "Referee anterior tiene partido propio"

4.5 Continuar hasta finals
    → Bronca-cerveza resuelta
    → Finals completadas
    → Torneos en status COMPLETED
```

### Fase 5: Verificación Post-Torneo

```
5.1 Verificar stats de referees
    → Query referee_assignments
    → Verificar matches arbitrado por cada referee

5.2 Verificar ELOs finales
    → Jugadores que arbitaron tienen ELO actualizado
    → Ranks (Bronze-Diamond) recalculados

5.3 Verificar community_feed
    → Eventos de UPSET si hubo sorpresas
    → Eventos de CHAMPION en finals
```

## Validaciones Críticas

| Validación | Esperado | Resultado |
|------------|----------|-----------|
| Shadow profiles no aparecen en available_referees | ✅ 8 shadow excluidos | PASS/FAIL |
| Jugador no puede arbitrar su propio match | ✅ Bloqueado por RLS | PASS/FAIL |
| Externo puede arbitrar cualquier match | ✅ Permitido | PASS/FAIL |
| Organizador puede reasignar cualquier match | ✅ Tiene permisos | PASS/FAIL |
| ELO se calcula correctamente | ✅ Fórmulas verificadas | PASS/FAIL |
| Voluntarios round-robin balanceados | ✅ ~2-3 matches por referee | PASS/FAIL |

## Criterios de Éxito

- [ ] 16 jugadores dummy creados (8 con auth, 8 shadow)
- [ ] 2 categorías creadas con rangos ELO distintos
- [ ] 1 organizador + 2 external referees invitados y aceptados
- [ ] 8 jugadores checked-in se ofrecen como voluntarios
- [ ] Sistema sugiere refs automáticamente (round-robin)
- [ ] Organizador puede confirmar/override sugerencias
- [ ] Scores ingresados solo por referees asignados
- [ ] Matches completados con ELO actualizado
- [ ] Referees liberados para siguientes fases
- [ ] 2 tournaments finalizados correctamente
