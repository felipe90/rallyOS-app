# CU-10: Jugador Ve Feed de Actividad

## Actor
- Jugador o espectador autenticado

## Objetivo
Ver el feed de actividad de un torneo

## Precondiciones
- Usuario está autenticado
- Tournament existe

## Flujo Principal

### Paso 1: Usuario selecciona torneo
El usuario:
1. Ve lista de torneos
2. Selecciona un torneo
3. Accede a la pestaña "Actividad" o "Feed"

### Paso 2: Sistema recupera feed
El sistema:
1. SELECT de `community_feed` WHERE tournament_id = X
2. Ordena por created_at DESC
3. Incluye payload_json para cada evento

### Paso 3: Sistema muestra feed
El sistema renderiza:
- ANNOUNCEMENT: "📢 [mensaje del organizador]"
- ENTRY_REGISTERED: "✅ [jugador] se registró en [categoría]"
- MATCH_COMPLETED: "🏆 [jugador A] venció a [jugador B] en [score]"
- BRACKET_GENERATED: "📊 Bracket generado para [categoría]"
- TOURNAMENT_STARTED: "🎬 ¡El torneo ha comenzado!"
- TOURNAMENT_COMPLETED: "🏅 ¡Torneo finalizado! Ganador: [nombre]"

### Paso 4: Usuario puede filtrar
El usuario puede:
- Filtrar por tipo de evento
- Filtrar por categoría
- Ver solo sus propios eventos

## Postcondiciones
- Feed visible en orden cronológico inverso

## Notas
- Feed es de solo lectura para usuarios
- Solo staff y triggers generan eventos
