# SPEC-TT-03: Group Seeding (Siembra)

## Purpose

Definir el sistema de siembra que distribuye los mejores jugadores en grupos separados para garantizar competencia justa.

## Requirements

### Requirement: Seeding Definition

El sistema DEBE soportar "cabezas de grupo" (seeds):

- Los mejores jugadores según ranking ELO se distribuyen en grupos separados
- Objetivo: que el #1 no juegue contra #2 hasta la final o semifinal

#### Scenario: Siembra automática de 8 jugadores en 4 grupos
- GIVEN 16 jugadores inscritos
- AND sistema genera 4 grupos de 4
- WHEN organizador ejecuta "Sembrar Grupos"
- THEN:
  - #1 → Grupo A (Seed 1A)
  - #2 → Grupo B (Seed 1B)
  - #3 → Grupo C (Seed 1C)
  - #4 → Grupo D (Seed 1D)
  - #5 → Grupo A (Seed 2A)
  - #6 → Grupo B (Seed 2B)
  - #7 → Grupo C (Seed 2C)
  - #8 → Grupo D (Seed 2D)
  - Los demás se distribuyen aleatoriamente

### Requirement: Seed Placement

El sistema DEBE definir posición del seed en el grupo:

#### Scenario: Seed 1A en Grupo A
- GIVEN jugador #1 seedeado en Grupo A
- WHEN sistema genera schedule de round-robin
- THEN jugador #1 se coloca en primera posición del grupo
- AND su primer partido es contra Seed 2A (#5)

#### Scenario: Equilibrio de seeding
- GIVEN 8 jugadores seeded, 8 random
- WHEN organizador ejecuta siembra
- THEN cada grupo recibe:
  - 1 seed alto (1-4)
  - 1 seed bajo (5-8)
  - 2 random

### Requirement: Manual Seed Override

El organizador PUEDE ajustar seeds manualmente:

#### Scenario: Mover jugador a otro grupo
- GIVEN jugador P1 está en Grupo A
- WHEN organizador mueve P1 a Grupo B
- THEN:
  - P1 sale de Grupo A
  - P1 entra en Grupo B
  - Sistema rebalancea automáticamente

#### Scenario: Promover jugador no seeded
- GIVEN jugador P10 no tiene seed alto
- WHEN organizador lo promueve como Seed 2A
- THEN P10 reemplaza al seed original en su grupo
- AND el seed original se mueve a grupo disponible

### Requirement: Seeding Criteria

El sistema DEBE usar los siguientes criterios para seeding:

| Criterio | Prioridad | Descripción |
|----------|-----------|-------------|
| ELO Ranking | 1 | Mayor ELO = mejor seed |
| Partidos jugados | 2 | Desempate |
| Historial vs jugadores seeded | 3 | Head-to-head |
| Admisión manual | 4 | Organizador puede override |

#### Scenario: Seed por ELO
- GIVEN jugadores con diferentes ELOs:
  - J1: 1200
  - J2: 1150
  - J3: 1100
  - J4: 1050
- WHEN organizador ejecuta siembra
- THEN:
  - J1 (#1 ELO) → Seed 1A
  - J2 (#2 ELO) → Seed 1B
  - J3 (#3 ELO) → Seed 1C
  - J4 (#4 ELO) → Seed 1D

### Requirement: Bye Distribution

El sistema DEBE manejar BYEs en grupos impares:

#### Scenario: 7 jugadores en grupo de 4
- GIVEN 7 jugadores quieren entrar a grupo "A" (máx 4)
- WHEN organizador intenta agregar 3 más
- THEN sistema sugiere crear Grupo "B" o mover jugadores

#### Scenario: BYE automático en scheduling
- GIVEN grupo con 5 jugadores
- WHEN sistema genera round-robin
- THEN cada ronda 1 jugador tiene BYE
- AND el BYE se registra como partido ganado 3-0
