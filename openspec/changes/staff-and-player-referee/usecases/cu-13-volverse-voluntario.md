# CU-13: Volverse Voluntario para Arbitrar (Player)

## Actor
Jugador registrado y checked-in en un torneo

## Objetivo
Ofrecerse como voluntario para arbitrar matches donde el jugador no participa.

## Precondiciones
- Usuario autenticado con person_id linked
- Usuario tiene registro en tournament_entries del torneo
- Usuario ha completado check-in (checked_in_at IS NOT NULL)
- Torneo en status CHECK_IN o LIVE

## Flujo Principal

### 13.1 Activar Voluntario

1. Jugador abre sección del torneo
2. Sistema muestra opciones de participación
3. Jugador hace clic en "Quiero arbitrar"
4. Sistema verifica precondiciones
5. Sistema muestra términos: "Dispones para arbitrar matches donde no juegues"
6. Jugador confirma
7. Sistema crea/actualiza registro en referee_volunteers
8. Sistema actualiza tournament_staff con rol PLAYER_REFEREE, status ACTIVE
9. Sistema muestra confirmación y opciones de arbitraje

**Resultado**: Jugador visible en available_referees.

### 13.2 Desactivar Voluntario

1. Jugador abre sección del torneo
2. Jugador hace clic en "Ya no quiero arbitrar"
3. Sistema solicita confirmación
4. Sistema actualiza referee_volunteers.is_active = false
5. Sistema actualiza tournament_staff status = REVOKED
6. Sistema remueve al jugador de available_referees
7. Sistema notifica si hay assignments activos pendientes

**Resultado**: Jugador no disponible para arbitrar.

## Flujos Alternativos

### 13.3 Intentar ser voluntario sin check-in
- GIVEN jugador registrado pero NO checked-in
- WHEN jugador intenta activarse como voluntario
- THEN sistema rechaza con error "Debes hacer check-in primero"

### 13.4 Intentar ser voluntario sin user_id linked
- GIVEN jugador con persona pero sin auth.users link
- WHEN jugador intenta activarse como voluntario
- THEN sistema rechaza con error "Necesitas cuenta vinculada para arbitrar"

### 13.5 Voluntario durante fase de grupos
- GIVEN torneo en fase de grupos
- AND jugador tiene matches pendientes en esa fase
- WHEN jugador se activa como voluntario
- THEN sistema permite pero muestra warning: "Tienes partidos pendientes, podrás arbitrar matches de otras llaves"

## Postcondiciones
- referee_volunteers actualizado
- tournament_staff refleja PLAYER_REFEREE status
- Jugador aparece/desaparece de available_referees
