# CU-14: Sistema de Sugerencias Automáticas de Referees

## Actor
Sistema (automático) / Organizador (manual)

## Objetivo
Asignar referees disponibles a matches de manera automática usando round-robin.

## Precondiciones
- Torneos en fase de generación de brackets
- Al menos un voluntario (PLAYER_REFEREE o EXTERNAL_REFEREE) disponible
- Matches creados sin referee_id

## Flujo Principal

### 14.1 Generación Automática de Sugerencias

1. Organizador ejecuta "Generar Brackets"
2. Sistema crea estructura de matches
3. Sistema ejecuta `generate_referee_suggestions(category_id)`
4. Sistema consulta available_referees para cada match
5. Sistema aplica algoritmo round-robin:
   a. Ordena voluntarios por `matches_refereed` ASC (menos arbitró primero)
   b. Asigna cada match a voluntario disponible
   c. Prioriza voluntarios no asignados aún en el round
6. Sistema marca assignments como `suggested` (pendiente de confirmación)
7. Sistema muestra vista de bracket con sugerencias

**Resultado**: Matches tienen referee sugerido, marcado como pendiente.

### 14.2 Confirmación Masiva de Sugerencias

1. Organizador revisa bracket con sugerencias
2. Sistema muestra: "X matches con referee sugerido"
3. Organizador hace clic en "Confirmar Todos"
4. Sistema actualiza todos `suggested → confirmed`
5. Sistema actualiza `matches.referee_id`
6. Sistema inserta registros en referee_assignments

**Resultado**: Todos los assignments confirmados.

## Flujos Alternativos

### 14.3 Menos voluntarios que matches
- GIVEN 3 voluntarios y 5 matches
- WHEN sistema ejecuta sugerencias
- THEN 3 matches reciben suggestion
- AND 2 matches quedan sin referee
- AND sistema muestra warning: "X matches sin referee disponible"

### 14.4 Override de Sugerencia Individual
- GIVEN match con referee sugerido
- WHEN Organizador hace clic en el match
- THEN sistema muestra modal con:
  - Referee actual (sugerido)
  - Lista de available_referees para ese match
  - Opción "Ninguno" para desasignar
- Organizador selecciona nuevo referee
- Sistema actualiza assignment

### 14.5 Sin voluntarios disponibles
- GIVEN torneo sin ningún referee disponible
- WHEN sistema intenta generar sugerencias
- THEN no se crean suggestions
- AND sistema muestra info: "Sin voluntarios disponibles"
- AND Organizador debe invitar/asignar referees manualmente

## Postcondiciones
- Matches tienen referee_id asignado o NULL
- referee_assignments tiene registro de cada assignment
- volunteers` matches_refereed actualizado
- Audit trail de overrides (si los hubo)
