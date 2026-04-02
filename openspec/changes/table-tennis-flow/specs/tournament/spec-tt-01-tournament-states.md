# SPEC-TT-01: Tournament Phases & States

## Purpose

Definir los estados y transiciones del ciclo de vida del torneo de tenis de mesa, desde la creación hasta el cierre.

## Requirements

### Requirement: Tournament Status States

El sistema DEBE soportar los siguientes estados del torneo:

| Estado | Descripción | Transiciones válidas |
|--------|-------------|---------------------|
| `DRAFT` | Borrador, configurable | → REGISTRATION |
| `REGISTRATION` | Inscripciones abiertas | → PRE_TOURNAMENT, → CANCELLED |
| `PRE_TOURNAMENT` | Pre-torneo, día antes | → CHECK_IN, → CANCELLED |
| `CHECK_IN` | Día del torneo, check-in | → LIVE, → CANCELLED |
| `LIVE` | Torneo en progreso | → COMPLETED, → SUSPENDED |
| `SUSPENDED` | Pausado | → LIVE, → CANCELLED |
| `COMPLETED` | Finalizado | (terminal) |
| `CANCELLED` | Cancelado | (terminal) |

### Requirement: Phase Entry Criteria

Cada fase tiene criterios de entrada:

#### Scenario: Avanza a REGISTRATION
- GIVEN torneo en DRAFT
- WHEN organizador configura fecha, hora, lieu, costo
- AND organizador publica el torneo
- THEN status cambia a REGISTRATION
- AND se habilita link de inscripción externo

#### Scenario: Avanza a PRE_TOURNAMENT
- GIVEN torneo en REGISTRATION
- WHEN organizador hace clic en "Preparar Torneo"
- THEN status cambia a PRE_TOURNAMENT
- AND organizador puede crear grupos

#### Scenario: Avanza a CHECK_IN
- GIVEN torneo en PRE_TOURNAMENT
- WHEN organizador inicia día del torneo
- THEN status cambia a CHECK_IN
- AND jugadores pueden confirmar asistencia

#### Scenario: Avanza a LIVE
- GIVEN torneo en CHECK_IN
- WHEN organizador inicia torneo
- THEN status cambia a LIVE
- AND grupos se confirman definitivamente
- AND comienza fase Round Robin

### Requirement: Check-In Attendance

El sistema DEBE permitir ajuste de grupos basado en asistencia:

#### Scenario: Jugador presente en check-in
- GIVEN torneo en CHECK_IN
- WHEN jugador confirma asistencia
- THEN jugador permanece en su grupo asignado

#### Scenario: Jugador ausente en check-in
- GIVEN torneo en CHECK_IN
- WHEN jugador no confirma asistencia
- THEN organizador puede:
  - Eliminarlo del grupo (juegan menos personas)
  - Moverlo a otro grupo si hay espacio
  - Mantenerlo y marcarlo como W/O en sus partidos

### Requirement: Tournament Suspension

El sistema DEBE permitir pausar el torneo:

#### Scenario: Suspender torneo
- GIVEN torneo en LIVE
- WHEN organizador suspende por emergencia
- THEN status cambia a SUSPENDED
- AND todos los matches activos se pausan
- AND tiempos de pausa se registran

#### Scenario: Reanudar torneo
- GIVEN torneo en SUSPENDED
- WHEN organizador reanuda
- THEN status vuelve a LIVE
- AND matches continúan desde estado pausado
