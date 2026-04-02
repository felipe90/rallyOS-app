# CU-12: Aceptar/Rechazar Invitación de Referee

## Actor
Usuario invitado a ser EXTERNAL_REFEREE

## Objetivo
Aceptar o rechazar una invitación para participar como referee externo en un torneo.

## Precondiciones
- Usuario autenticado
- Existe invitación pendiente (status PENDING) para el usuario
- Invitación no ha expirado (menos de 7 días)

## Flujo Principal

### 12.1 Aceptar Invitación

1. Usuario recibe notificación de invitación pendiente
2. Usuario abre sección "Mis Torneos" → "Invitaciones"
3. Sistema muestra lista de invitaciones pendientes
4. Usuario selecciona invitación
5. Sistema muestra detalles del torneo y rol
6. Usuario hace clic en "Aceptar"
7. Sistema actualiza status de PENDING → ACTIVE
8. Sistema muestra confirmación
9. Sistema actualiza RLS para permitir arbitraje

**Resultado**: Usuario tiene permisos de EXTERNAL_REFEREE activos.

### 12.2 Rechazar Invitación

1. Usuario recibe notificación de invitación pendiente
2. Usuario abre sección "Mis Torneos" → "Invitaciones"
3. Sistema muestra lista de invitaciones pendientes
4. Usuario selecciona invitación
5. Usuario hace clic en "Rechazar"
6. Sistema solicita confirmación
7. Sistema actualiza status de PENDING → REJECTED
8. Sistema notifica al organizador

**Resultado**: Invitación rechazada, sin permisos.

## Flujos Alternativos

### 12.3 Aceptar invitación expirada
- GIVEN invitación con más de 7 días de antigüedad
- WHEN usuario intenta aceptar
- THEN sistema rechaza con error "Invitación expirada"
- **Acción**: Organizador debe enviar nueva invitación

### 12.4 Aceptar invitación ya aceptada
- GIVEN invitación con status ACTIVE
- WHEN usuario intenta aceptar nuevamente
- THEN sistema rechaza con error "Invitación ya была принята"

### 12.5 Invitación revocada antes de aceptación
- GIVEN invitación con status PENDING
- AND organizador revocó la invitación
- WHEN usuario intenta aceptar
- THEN sistema rechaza con error "Invitación была отозвана"

## Postcondiciones
- Status de invitación actualizado
- Permisos otorgados o negados según respuesta
- Notificación enviada al organizador
