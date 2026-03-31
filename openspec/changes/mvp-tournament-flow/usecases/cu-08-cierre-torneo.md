# CU-08: Organizador Cierra Torneo

## Actor
- Organizador del torneo

## Objetivo
Finalizar el torneo y lockear resultados

## Precondiciones
- Tournament.status = 'LIVE'
- Todos los matches están en FINISHED o W_O

## Flujo Principal

### Paso 1: Organizador inicia cierre
El organizador:
1. Ve panel de control
2. Verifica que todos los partidos terminaron
3. Clic en "Finalizar Torneo"

### Paso 2: Sistema valida
El sistema verifica:
- Todos los matches de todas las categorías están FINISHED o W_O
- No hay matches en estado SUSPENDED

### Paso 3: Sistema cierra tournament
El sistema:
1. UPDATE tournament.status = 'COMPLETED'
2. INSERT en `community_feed` (TOURNAMENT_COMPLETED)
3. Locks todas las entries

### Paso 4: Reporte final
El sistema muestra:
- Resultados finales
- Campeón de cada categoría
- Top ELO gainers del torneo

## Postcondiciones
- Tournament.status = 'COMPLETED'
- No se pueden hacer más cambios

## Excepciones

### E-01: Matches pendientes
- Sistema muestra: "Hay X partidos sin terminar"
- Lista los partidos pendientes

### E-02: Match SUSPENDED
- Sistema muestra: "No se puede cerrar torneo con partidos suspendidos"
- Opción de declarar W_O o esperar
