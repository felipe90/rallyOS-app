# CU-04: Organizador Genera Bracket

## Actor
- Organizador del torneo

## Objetivo
Generar el bracket de eliminación directa con los jugadores confirmados

## Precondiciones
- Torneo está en estado CHECK_IN
- Mínimo 2 entries en estado CONFIRMED
- Bracket no ha sido generado (categories.bracket_generated = FALSE)

## Flujo Principal

### Paso 1: Organizador inicia generación
El organizador:
1. Ve resumen de entries confirmadas por categoría
2. Clic en "Generar Bracket"

### Paso 2: Sistema genera matches
Para cada categoría:
1. Llama a función `generate_bracket(p_category_id)`
2. Función:
   - Obtiene entries CONFIRMED ordenados por ELO
   - Crea matches para cada ronda
   - Aplica seeding (ELO más alto vs más bajo)
   - Maneja BYEs automáticamente
   - Links matches via `next_match_id`

### Paso 3: Sistema actualiza estado
- UPDATE `categories.bracket_generated = TRUE`
- INSERT en `community_feed` (BRACKET_GENERATED)

### Paso 4: Sistema avanza torneo
- UPDATE `tournaments.status = 'LIVE'`

### Paso 5: Confirmación
El sistema muestra bracket generado con:
- Estructura visual del bracket
- Primer partido destacado

## Postcondiciones
- Matches existen en tabla `matches`
- Category.bracket_generated = TRUE
- Tournament.status = 'LIVE'

## Excepciones

### E-01: Bracket ya generado
- Sistema muestra: "El bracket ya fue generado para esta categoría"

### E-02: Tournament en LIVE
- Una vez en LIVE, no se puede regenerar bracket
