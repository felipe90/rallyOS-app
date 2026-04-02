# SPEC-TT-04: Intra-Group Referees

## Purpose

Definir que SOLO compañeros del mismo grupo pueden actuar como árbitros durante la fase Round Robin.

**CRÍTICO**: Esto es diferente al modelo actual donde cualquier jugador checked-in puede arbitrar. En tenis de mesa real, el árbitro es UN COMPAÑERO DEL GRUPO que no está jugando.

## Requirements

### Requirement: Intra-Group Referee Pool

El sistema DEBE generar pool de referees SOLO del MISMO grupo:

#### Scenario: Pool para Match A1 vs A2 en Grupo A
- GIVEN Grupo A con jugadores: A1, A2, A3, A4
- AND el partido actual es A1 vs A2
- WHEN sistema calcula available_referees para este partido
- THEN el pool es: [A3, A4] (los que NO están jugando)
- AND A1 y A2 NO pueden arbitrar su propio partido

#### Scenario: Pool con BYE
- GIVEN Grupo A con jugadores: A1, A2, A3, A4, A5 (BYE en ronda)
- AND el partido actual es A1 vs A2
- WHEN sistema calcula pool
- THEN el pool es: [A3, A4, A5(BYE)]
- AND A5 tiene prioridad como referee por tener BYE

### Requirement: Referee Assignment Rules

El referee DEBE cumplir:
1. Pertenecer al MISMO grupo
2. NO estar jugando el partido actual
3. Haber completado check-in
4. Tener user_id (shadow no puede arbitrar)

#### Scenario: Intentar asignar jugador de otro grupo
- GIVEN Grupo A (A1, A2, A3, A4) y Grupo B (B1, B2, B3, B4)
- AND partido es A1 vs A2
- WHEN organizador intenta asignar B3 como referee
- THEN sistema rechaza con error: "Referee debe ser del mismo grupo"

### Requirement: Referee Rotation

El sistema DEBE optimizar rotación de referees:

#### Scenario: Round-robin de arbitraje
- GIVEN Grupo A con 4 jugadores
- AND 6 partidos en round-robin
- WHEN sistema genera schedule
- THEN cada jugador arbitra ~1-2 partidos
- AND se priorizan jugadores con menos arbitrajes

#### Scenario: BYE como referee primario
- GIVEN jugador tiene BYE en una ronda
- WHEN hay partido en esa ronda
- THEN ese jugador tiene PRIORIDAD como referee
- AND jugadores con BYE no juegan pero SÍ arbitran

### Requirement: Manual Override (Intra-Group)

El organizador PUEDE reasignar referee dentro del grupo:

#### Scenario: Organizador cambia referee
- GIVEN partido A1 vs A2 con referee asignado A3
- WHEN organizador cambia a A4 como referee
- THEN:
  - A4 es el nuevo referee
  - A3 queda disponible para otra asignación
  - Se registra el cambio en auditoría

### Requirement: Loser Becomes Next Referee

**Regla especial del flujo real**: El jugador que pierde, arbitra el siguiente partido del ganador.

#### Scenario: A1 pierde vs A2
- GIVEN partido A1 vs A2
- AND el próximo partido del ganador (A2) es vs A3
- WHEN partido A1 vs A2 termina
- THEN sistema sugiere automáticamente:
  - A1 como referee del partido A2 vs A3
  - A1 sale del grupo de juego para esta ronda

#### Scenario: A1 pierde en cuartos, A2 avanza a semis
- GIVEN A1 pierde vs A2 en cuartos
- AND A2 avanza a semifinal vs C1
- WHEN partido cuartos termina
- THEN:
  - A1 es referee de SEMIFINAL (A2 vs C1)
  - A1 se mueve temporalmente al bracket de llaves
  - Después de semis, A1 puede volver a su grupo (si hay bronze)

### Requirement: Special Case - Loser from Same Group

Si el perdedor es del MISMO grupo que el próximo contrincante:

#### Scenario: A1 pierde vs A2, próximo partido de A2 es vs A3
- GIVEN A1 pierde vs A2
- AND A2 vs A3 es el siguiente partido (ambos del mismo grupo A)
- WHEN partido termina
- THEN:
  - A1 es referee de A2 vs A3
  - A1 es compañero de ambos, puede arbitrar
  - Esto es correcto y esperado

#### Scenario: A1 pierde vs A2, próximo partido de A2 es vs B1 (diferente grupo)
- GIVEN A1 pierde vs A2
- AND A2 vs B1 es el siguiente partido (diferente grupo)
- WHEN partido termina
- THEN:
  - A1 NO puede arbitrar (no es del grupo B)
  - Sistema busca referee de GRUPO B que no esté jugando
  - O el organizador asigna manualmente

### Requirement: Final Match Referee

En la FINAL no hay próximo partido del ganador:

#### Scenario: Final entre F1 y F2
- GIVEN Final F1 vs F2
- AND no hay partido después
- WHEN partido termina
- THEN:
  - El organizador designa referee para la final
  - Puede ser: perdedor del bronce, voluntario, u organizador mismo
