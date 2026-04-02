# SPEC-TT-02: Round Robin Groups

## Purpose

Definir la estructura y comportamiento de los grupos Round Robin en tournaments de tenis de mesa.

## Requirements

### Requirement: Group Structure

Un grupo DEBE contener:
- Identificador único (letra o número: A, B, C...)
- Lista de 3-5 jugadores
- Modalidad: siempre SINGLES para tenis de mesa
- Lista de partidos a jugar (round-robin completo)

#### Scenario: Crear grupo con 4 jugadores
- GIVEN torneo en PRE_TOURNAMENT
- WHEN organizador crea grupo "A" con 4 jugadores
- THEN sistema genera 6 partidos (n*(n-1)/2 = 4*3/2)
- AND scheduling de partidos muestra: A1 vs A2, A1 vs A3, A1 vs A4, A2 vs A3, A2 vs A4, A3 vs A4

#### Scenario: Crear grupo con 3 jugadores (mínimo)
- GIVEN torneo en PRE_TOURNAMENT
- WHEN organizador crea grupo "B" con 3 jugadores
- THEN sistema genera 3 partidos (3*2/2 = 3)

#### Scenario: Crear grupo con 5 jugadores (máximo)
- GIVEN torneo en PRE_TOURNAMENT
- WHEN organizador crea grupo "C" con 5 jugadores
- THEN sistema genera 10 partidos (5*4/2 = 10)

### Requirement: Round Robin Scheduling

El sistema DEBE generar scheduling de round-robin:

#### Scenario: Generar schedule para 4 jugadores
- GIVEN grupo "A" con jugadores P1, P2, P3, P4
- WHEN sistema genera round-robin
- THEN se generan partidos en orden:
  1. P1 vs P2
  2. P3 vs P4 (o BYE si impar)
  3. P1 vs P3
  4. P2 vs P4
  5. P1 vs P4
  6. P2 vs P3

#### Scenario: Grupo con jugadores impares (BYE)
- GIVEN grupo con 5 jugadores
- WHEN sistema genera schedule
- THEN un jugador recibe BYE cada ronda
- AND ese jugador no juega esa ronda pero se registra BYE

### Requirement: Group Classification

El sistema DEBE calcular clasificación post-round-robin:

#### Scenario: Clasificación por puntos
- GIVEN todos los partidos del grupo completados
- WHEN organizador solicita clasificación
- THEN sistema calcula:
  - Partidos ganados (3 puntos)
  - Partidos empatados (1 punto cada uno)
  - Partidos perdidos (0 puntos)
- AND ordena por total de puntos DESC
- AND desempate por diferencia de puntos

#### Scenario: Desempate
- GIVEN jugadores J1 y J2 con misma cantidad de puntos
- WHEN sistema calcula clasificación
- THEN usa:
  1. Resultado cabeza a cabeza entre J1 y J2
  2. Diferencia de puntos total
  3. Puntos a favor totales
  4. Puntos en contra totales

### Requirement: Flexible Group Sizes

El sistema DEBE permitir grupos de diferentes tamaños:

#### Scenario: Grupo con jugador eliminado
- GIVEN grupo "A" con 4 jugadores (6 partidos)
- AND 1 jugador no se presenta (W/O)
- WHEN organizador inicia el torneo
- THEN:
  - Grupo juega con 3 jugadores (3 partidos)
  - Jugador W/O recibe 0 puntos en partidos no jugados
  - Clasificación se recalcula

### Requirement: Group Advancement

El sistema DEBE manejar avance a llaves:

#### Scenario: Top 2 avanzan a llaves
- GIVEN grupo "A" completado
- WHEN organizador define "Top 2 avanzan"
- THEN los 2 mejores jugadores se seleccionan para llaves
- AND placement determina seed en llaves

#### Scenario: Todos avanzan a llaves (copa)
- GIVEN grupo "A" completado
- WHEN organizador define "Todos avanzan"
- THEN todos los jugadores avanzan
- AND se genera bracket de eliminación simple
