# CU-02: Jugador se Registra en Torneo

## Actor
- Jugador autenticado con perfil `persons` creado

## Objetivo
Registrarse como participante en un torneo

## Precondiciones
- Jugador tiene perfil `persons` creado (con user_id vinculado)
- Torneo está en estado REGISTRATION
- Categoría existe en el torneo
- Jugador no está ya registrado en esta categoría

## Flujo Principal

### Paso 1: Jugador selecciona torneo
El jugador:
1. Ve la lista de torneos en REGISTRATION
2. Selecciona un torneo
3. Ve las categorías disponibles

### Paso 2: Jugador selecciona categoría
El jugador selecciona la categoría (ej: "Men's Singles"):

### Paso 3: Sistema valida elegibilidad
El sistema verifica:
- Jugador tiene ELO dentro de elo_min y elo_max de la categoría
- Jugador no está ya registrado en esta categoría
- Categoría permite el game_mode (SINGLES, DOUBLES, TEAMS)

### Paso 4: Jugador ingresa datos
El jugador:
- Ingresa nombre del equipo/display_name
- Para DOUBLES/TEAMS: selecciona compañeros

### Paso 5: Sistema crea registro
El sistema:
1. INSERT en `tournament_entries` 
   - Si fee_amount = 0 → status = 'CONFIRMED' (auto-confirm)
   - Si fee_amount > 0 → status = 'PENDING_PAYMENT'
2. INSERT en `entry_members` para cada jugador
3. Si free tournament → INSERT en `community_feed` (ENTRY_REGISTERED)

### Paso 6: Confirmación
El sistema muestra:
- Entry ID
- Status de confirmación
- Para pagos: instrucciones de pago

## Postcondiciones
- Entry existe en `tournament_entries`
- Members existen en `entry_members`

## Excepciones

### E-01: ELO fuera de rango
- Sistema muestra: "Tu ELO no está dentro del rango permitido para esta categoría"

### E-02: Ya registrado
- Sistema muestra: "Ya estás registrado en este torneo"
- Bloqueado por SPEC-006 (trigger `trg_prevent_duplicate_registration`)

### E-03: Torneo no en REGISTRATION
- Sistema muestra: "Este torneo no está accepting registros"
