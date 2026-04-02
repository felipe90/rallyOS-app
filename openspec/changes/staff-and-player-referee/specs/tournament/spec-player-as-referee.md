# SPEC-011: Player-As-Referee System

## Purpose

Definir el sistema que permite a jugadores checked-in arbitrar matches donde no participan, con pool de disponibilidad y sistema de sugerencias automáticas.

## Requirements

### Requirement: Referee Pool (Available Referees)

El sistema DEBE mantener un pool de referees disponibles calculado dinámicamente.

La vista `available_referees(match_id)` DEBE retornar usuarios que:
1. Están checked-in en el torneo del match
2. Tienen `user_id` asociado (puede ser NULL para shadow profiles)
3. NO están jugando el match (ni en entry_a ni entry_b)
4. NO tienen assignment pendiente para otro match en el mismo round

#### Scenario: Jugador aparece como referee disponible
- GIVEN un torneo LIVE con 8 jugadores checked-in
- AND Match #1 tiene entry_a = JugadorA, entry_b = JugadorB
- WHEN Organizer consulta available_referees para Match #1
- THEN retorna 6 jugadores (A y B excluidos)

#### Scenario: Jugador no checked-in no aparece
- GIVEN un torneo donde JugadorC no ha hecho check-in
- WHEN Organizer consulta available_referees para cualquier match
- THEN JugadorC NO aparece en la lista

#### Scenario: Shadow profile no aparece
- GIVEN un torneo donde JugadorD tiene persona pero NO tiene user_id
- WHEN Organizer consulta available_referees para cualquier match
- THEN JugadorD NO aparece (requiere user_id para arbitrar)

### Requirement: Voluntad de Arbitrar

Jugadores checked-in PUEDEN marcar su disponibilidad:

#### Scenario: Jugador se ofrece como voluntario
- GIVEN un torneo LIVE y el usuario es jugador checked-in
- WHEN usuario ejecuta `toggle_referee_volunteer(tournament_id, true)`
- THEN se crea/actualiza registro en `referee_volunteers`
- AND el usuario aparece en suggestions

#### Scenario: Jugador retira disponibilidad
- GIVEN un torneo donde el usuario es voluntario activo
- WHEN usuario ejecuta `toggle_referee_volunteer(tournament_id, false)`
- THEN el registro se marca como inactivo
- AND el usuario se excluye de suggestions

### Requirement: Sistema de Sugerencias Automáticas

Cuando se genera el bracket, el sistema DEBE sugerir referees automáticamente:

#### Scenario: Sugerencia por round-robin
- GIVEN un torneo con N voluntarios disponibles
- AND M matches en la ronda actual (M <= N)
- WHEN se ejecuta `generate_referee_suggestions(category_id)`
- THEN cada match recibe un referee distinto
- AND se priorizan voluntarios que menos han arbitrado

#### Scenario: Más matches que voluntarios
- GIVEN un torneo con 3 voluntarios y 5 matches
- WHEN se ejecutan sugerencias
- THEN 3 matches reciben voluntarios
- AND 2 matches quedan sin referee sugerido

#### Scenario: Organizer override suggestion
- GIVEN un match con referee sugerido
- WHEN organizer ejecuta `assign_referee(match_id, user_id)`
- THEN el override reemplaza la sugerencia
- AND se registra el override en `referee_assignments`

### Requirement: Assignment de Referee a Match

Solo usuarios autorizados PUEDEN ser asignados como referees:

#### Scenario: Asignar PLAYER_REFEREE a match
- GIVEN Match #1 donde JugadorA y JugadorB juegan
- AND JugadorC está disponible
- WHEN organizer asigna JugadorC como referee
- THEN `matches.referee_id = JugadorC.user_id`
- AND JugadorC tiene permisos para ingresar scores

#### Scenario: Intento de auto-arbitraje bloqueado
- GIVEN Match #1 donde el usuario actual es entry_a
- WHEN usuario intenta asignarse como referee
- THEN el sistema rechaza con error "No puedes arbitrar tu propio match"

#### Scenario: Intento de asignar referee no disponible
- GIVEN JugadorD no está checked-in
- WHEN organizer intenta asignar JugadorD como referee
- THEN el sistema rechaza con error "Jugador no disponible"

### Requirement: Revocar Assignment de Match

Organizer PUEDE remover/refrescar assignment de referee:

#### Scenario: Organizer remueve referee de match
- GIVEN un match con referee asignado
- WHEN organizer ejecuta `clear_match_referee(match_id)`
- THEN `matches.referee_id = NULL`
- AND el match queda disponible para reasignación

#### Scenario: Match completado libera al referee
- GIVEN un match con referee JugadorC
- WHEN se ejecuta `process_match_completion(match_id)`
- THEN JugadorC queda automáticamente disponible
- AND puede ser asignado a matches de siguientes rondas

### Requirement: Tracking de Assignments

El sistema DEBE mantener historial de assignments para estadísticas:

#### Scenario: Registro de assignment
- GIVEN un match donde se asigna JugadorC como referee
- WHEN se ejecuta `assign_referee(match_id, user_id)`
- THEN se inserta registro en `referee_assignments`
- AND se incrementa `matches_refereed` del jugador

#### Scenario: Estadísticas por jugador
- GIVEN un torneo con múltiples assignments
- WHEN se consulta `get_referee_stats(person_id, tournament_id)`
- THEN se retorna cantidad de matches arbitrado y rounds completados
