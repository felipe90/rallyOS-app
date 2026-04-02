# SPEC-TT-05: Manual Score Entry

## Purpose

Definir el flujo de registro de scores manual durante y después de cada fase del torneo.

## Requirements

### Requirement: Post-Match Score Entry

El referee o organizador DEBE poder ingresar scores después de cada partido:

#### Scenario: Ingresar score post-partido
- GIVEN partido completado
- WHEN referee o organizador ingresa resultado
- THEN sistema registra:
  - Marcador final (ej: 11-8, 11-9, 8-11)
  - Sets jugados
  - Ganador
  - Timestamp

#### Scenario: Score entry en planilla física
- GIVEN torneo en progreso
- AND referee anota score en planilla física
- WHEN organizador luego ingresa digitalmente
- THEN sistema acepta el score
- AND se actualiza clasificación/bracket

### Requirement: Score Validation

El sistema DEBE validar scores según formato del deporte:

#### Scenario: Score válido (Tenis de Mesa)
- GIVEN deporte = Table Tennis
- WHEN referee ingresa: 11-8
- THEN sistema valida:
  - Winner ≥ 11
  - Winner - Loser ≥ 2
  - Máximo 11 puntos si hay win-by-2
- AND acepta score

#### Scenario: Score inválido
- GIVEN Table Tennis
- WHEN referee ingresa: 10-8
- THEN sistema rechaza con error: "En Table Tennis, winner debe tener mínimo 11 puntos"

### Requirement: Set-by-Set Entry

El sistema DEBE permitir ingreso set por set:

#### Scenario: Ingresar sets individuales
- GIVEN match al mejor de 5
- WHEN referee ingresa sets:
  - Set 1: 11-8 (Player A wins)
  - Set 2: 9-11 (Player B wins)
  - Set 3: 11-7 (Player A wins)
  - Set 4: 5-11 (Player B wins)
  - Set 5: 11-9 (Player A wins)
- THEN sistema detecta:
  - Player A gana 3-2
  - Match completo
  - Avanza al siguiente partido

### Requirement: Offline Score Entry

El sistema DEBE funcionar offline para registro en papel:

#### Scenario: Registro offline
- GIVEN torneo en lugar sin internet
- AND referee tiene celular sin conexión
- WHEN referee ingresa scores en app
- THEN:
  - App guarda localmente
  - Muestra "pending sync"
  - Cuando hay conexión, sincroniza
  - Conflictos se resuelven con last-write-wins

### Requirement: Score Confirmation

El sistema DEBE requerir confirmación:

#### Scenario: Confirmation de score
- GIVEN referee ingresa score
- WHEN ambos jugadores confirman
- THEN score se locking (no editable)
- AND se actualiza clasificación

#### Scenario: Disputa de score
- GIVEN score ingresado
- WHEN jugador discrepancy dice "score incorrecto"
- THEN:
  - Organizador puede hacer override
  - Se registra quien hizo override
  - Se deja nota de dispute

### Requirement: Round Robin Summary Entry

El organizador PUEDE ingresar resumen completo del grupo:

#### Scenario: Entrada masiva de resultados
- GIVEN todos los partidos de Grupo A completados
- WHEN organizador ingresa resumen:
  ```
  A1 2-0 A2 (11-8, 11-9)
  A1 1-1 A3 (11-7, 8-11)
  A1 0-2 A4 (9-11, 10-12)
  A2 2-0 A3 (11-5, 11-6)
  A2 1-1 A4 (11-9, 8-11)
  A3 2-0 A4 (11-10, 11-8)
  ```
- THEN sistema calcula automáticamente:
  - Puntos: A1=4, A2=5, A3=3, A4=3
  - Clasificación final
  - Avances a llaves

### Requirement: Score History

El sistema DEBE mantener historial de cambios:

#### Scenario: Score modificado después
- GIVEN score original: 11-8
- WHEN organizador modifica a: 11-9
- THEN sistema guarda:
  - Original: 11-8
  - Modificado: 11-9
  - Timestamp de cambio
  - Usuario que modificó
