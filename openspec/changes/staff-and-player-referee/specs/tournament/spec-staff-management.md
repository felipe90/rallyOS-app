# SPEC-010: Tournament Staff Management

## Purpose

Define el sistema de gestión de staff para torneos con soporte para múltiples roles, modos de asignación (automático e invitación), y control de permisos granular.

## Requirements

### Requirement: Staff Roles

El sistema DEBE soportar exactamente 3 roles de staff:

| Rol | Descripción | Permisos |
|-----|-------------|----------|
| `ORGANIZER` | Creador/dueño del torneo | Todos: staff, categorías, brackets, scores |
| `EXTERNAL_REFEREE` | Arbitro externo asignado | Arbitrar matches asignados, ver scores |
| `PLAYER_REFEREE` | Jugador checked-in que no juega el match | Arbitrar matches donde no participa |

#### Scenario: Organizer crea torneo
- GIVEN un usuario autenticado
- WHEN crea un torneo
- THEN el usuario es asignado automáticamente como ORGANIZER

#### Scenario: Organizer asigna external referee
- GIVEN un torneo con status DRAFT o REGISTRATION
- WHEN organizer asigna un usuario como EXTERNAL_REFEREE
- THEN el usuario recibe rol EXTERNAL_REFEREE
- AND puede ser asignado a matches del torneo

#### Scenario: Jugador se vuelve PLAYER_REFEREE
- GIVEN un torneo en status CHECK_IN o LIVE
- AND un jugador checked-in con user_id asociado
- WHEN el jugador ejecuta `toggle_volunteer(true)`
- THEN el jugador aparece en `available_referees`

### Requirement: Staff Status

Cada registro en `tournament_staff` DEBE tener un status:

| Status | Usado para | Significado |
|--------|------------|-------------|
| `ACTIVE` | ORGANIZER, PLAYER_REFEREE | Tiene permisos activos |
| `PENDING` | EXTERNAL_REFEREE | Invitación enviada, esperando aceptación |
| `REJECTED` | EXTERNAL_REFEREE | Invitación rechazada |
| `REVOKED` | Todos | Permiso removido |

#### Scenario: Invitación pendiente expira
- GIVEN una invitación con status PENDING
- WHEN pasan 7 días sin respuesta
- THEN el status cambia a `REVOKED` automáticamente

### Requirement: Modo Automático de Asignación

Organizer PUEDE asignar staff directamente sin invitación:

#### Scenario: Asignación directa
- GIVEN un torneo
- WHEN organizer asigna rol EXTERNAL_REFEREE a un usuario
- THEN el registro se crea con status `ACTIVE`
- AND el usuario tiene permisos inmediatos

### Requirement: Modo por Invitación de Asignación

Organizer PUEDE invitar usuarios que deben aceptar:

#### Scenario: Organizer envía invitación
- GIVEN un torneo
- WHEN organizer invita a un usuario como EXTERNAL_REFEREE
- THEN se crea registro con status `PENDING`
- AND `invited_by` apunta al organizer

#### Scenario: Usuario acepta invitación
- GIVEN una invitación pendiente para el usuario actual
- WHEN usuario ejecuta `accept_invitation(tournament_id)`
- THEN el status cambia a `ACTIVE`
- AND el usuario tiene permisos de EXTERNAL_REFEREE

#### Scenario: Usuario rechaza invitación
- GIVEN una invitación pendiente para el usuario actual
- WHEN usuario ejecuta `reject_invitation(tournament_id)`
- THEN el status cambia a `REJECTED`
- AND no se otorgan permisos

### Requirement: Revocación de Staff

Solo ORGANIZER PUEDE revocar roles:

#### Scenario: Organizer revoca referee
- GIVEN un torneo con un staff activo
- WHEN organizer ejecuta `revoke_staff(user_id)`
- THEN el registro cambia a `REVOKED`
- AND el usuario pierde acceso inmediato

#### Scenario: Self-removal de PLAYER_REFEREE
- GIVEN un torneo donde el usuario es PLAYER_REFEREE activo
- WHEN usuario ejecuta `toggle_volunteer(false)`
- THEN el registro cambia a `REVOKED`
- AND el usuario ya no aparece en available_referees

### Requirement: Permisos por Rol

| Operación | ORGANIZER | EXTERNAL_REFEREE | PLAYER_REFEREE |
|-----------|-----------|------------------|----------------|
| Gestionar staff | ✅ | ❌ | ❌ |
| Gestionar categorías | ✅ | ❌ | ❌ |
| Generar brackets | ✅ | ❌ | ❌ |
| Arbitrar matches | ✅ | ✅ (asignado) | ✅ (no jugando) |
| Ingresar scores | ✅ | ✅ (asignado) | ✅ (asignado) |
| Cerrar torneo | ✅ | ❌ | ❌ |
