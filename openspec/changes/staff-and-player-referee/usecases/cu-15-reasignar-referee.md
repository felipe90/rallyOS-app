# CU-15: Reasignar/Clear Referee en Match

## Actor
Organizador del torneo

## Objetivo
Reasignar o remover el referee asignado a un match específico durante el torneo.

## Precondiciones
- Usuario es ORGANIZER del torneo
- Match existe en el torneo
- Match está en status SCHEDULED o CALLING

## Flujo Principal

### 15.1 Reasignar Referee

1. Organizador abre vista de bracket/matches
2. Organizador selecciona match específico
3. Sistema muestra panel lateral con:
   - Referee actual (si existe)
   - Lista de available_referees para ese match
   - Opción "Ninguno"
4. Organizador selecciona nuevo referee
5. Sistema valida:
   - Usuario seleccionado no está en entry_a ni entry_b
   - Usuario tiene status ACTIVE en tournament_staff
6. Sistema actualiza `matches.referee_id`
7. Sistema crea registro en referee_assignments
8. Sistema actualiza stats del referee anterior (si existía)

**Resultado**: Match tiene nuevo referee.

### 15.2 Remover Referee (Dejar Sin Asignar)

1. Organizador abre vista de match
2. Organizador selecciona opción "Ninguno"
3. Sistema solicita confirmación
4. Sistema actualiza `matches.referee_id = NULL`
5. Sistema no crea nuevo referee_assignment

**Resultado**: Match sin referee, disponible para reasignación.

## Flujos Alternativos

### 15.3 Reasignar en Match LIVE
- GIVEN match en status LIVE
- AND referee actual está presente pero no puede continuar
- WHEN Organizador intenta reasignar
- THEN sistema permite reasignación
- AND muestra warning: "Match en progreso, el cambio apply a partir del siguiente punto"

### 15.4 Reasignar en Match FINISHED
- GIVEN match en status FINISHED
- WHEN Organizador intenta reasignar
- THEN sistema rechaza con error "No se puede reasignar partido finalizado"

### 15.5 Intentar asignar jugador del match
- GIVEN Match con entry_a = JugadorA
- WHEN Organizador intenta asignar JugadorA como referee
- THEN sistema rechaza con error "El jugador participa en este match"

## Postcondiciones
- Match tiene referee_id actualizado
- referee_assignments refleja historial
- Stats de referees actualizados
