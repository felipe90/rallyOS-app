# CU-11: Gestionar Staff del Torneo

## Actor
Organizador del torneo

## Objetivo
Invitar, asignar o remover miembros del staff del torneo con control granular de roles.

## Precondiciones
- Usuario autenticado
- Usuario es ORGANIZER del torneo
- Torneo en status DRAFT, REGISTRATION o CHECK_IN

## Flujo Principal

### 11.1 Invitar Referee Externo (Modo Invitación)

1. Organizador abre panel de gestión de staff
2. Sistema muestra lista de usuarios o permite buscar por email
3. Organizador selecciona usuario objetivo
4. Organizador elige rol EXTERNAL_REFEREE
5. Organizador selecciona modo "Invitar" (por defecto)
6. Sistema crea registro en tournament_staff con status PENDING
7. Sistema registra invited_by = organizer's user_id
8. Sistema envía notificación al invitado (futuro: email)

**Resultado**: Invitación enviada, esperando aceptación.

### 11.2 Asignar Referee Directamente (Modo Automático)

1. Organizador abre panel de gestión de staff
2. Organizador selecciona usuario objetivo
3. Organizador elige rol (EXTERNAL_REFEREE o PLAYER_REFEREE)
4. Organizador selecciona modo "Asignar directamente"
5. Sistema crea/actualiza registro con status ACTIVE
6. Sistema otorga permisos inmediatos

**Resultado**: Staff asignado con permisos activos.

### 11.3 Revocar Staff

1. Organizador abre panel de gestión de staff
2. Organizador selecciona miembro a remover
3. Organizador confirma la acción
4. Sistema actualiza status a REVOKED
5. Sistema remueve inmediatamente los permisos

**Resultado**: Staff removido, sin permisos.

## Flujos Alternativos

### 11.4 Intentar gestionar staff en torneo LIVE
- GIVEN torneo en status LIVE
- WHEN ORGANIZER intenta invitar/nombrar nuevo staff
- THEN sistema rechaza con error "Torneo en progreso, no se puede modificar staff"
- **Excepción**: Sí se puede asignar/reasignar referees a matches individuales

### 11.5 Intentar gestionar staff sin ser ORGANIZER
- GIVEN usuario que no es ORGANIZER
- WHEN intenta cualquier operación de gestión de staff
- THEN sistema rechaza con error "Permiso denegado"

## Postcondiciones
- Staff agregado/actualizado en tournament_staff
- Permisos reflejados en RLS policies
- Audit log generado
