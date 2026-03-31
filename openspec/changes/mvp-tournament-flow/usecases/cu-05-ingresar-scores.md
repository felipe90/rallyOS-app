# CU-05: Árbitro Ingresa Scores

## Actor
- Árbitro asignado al partido
- Organizador (puede arbitrAR cualquier partido)

## Objetivo
Registrar los scores de un partido en vivo

## Precondiciones
- Match está en estado LIVE
- User es referee_id del match O es ORGANIZER

## Flujo Principal

### Paso 1: Árbitro accede al partido
El árbitro:
1. Ve lista de sus partidos asignados
2. Selecciona partido en LIVE

### Paso 2: Árbitro ingresa set
El árbitro ingresa resultado de cada set:
- Puntos de entry_a
- Puntos de entry_b

### Paso 3: Sistema guarda score
El sistema:
1. UPDATE `scores` con:
   - points_a = valor ingresado
   - points_b = valor ingresado
   - current_set++
   - sets_json = append nuevo set
   - local_updated_at = NOW()

### Paso 4: Árbitro indica fin de set
El árbitro indica "Set Completado"

### Paso 5: Sistema verifica winner del set
El sistema determina:
- Si points_a > points_b → entry_a gana set
- Si points_b > points_a → entry_b gana set

### Paso 6: Árbitro indica fin del partido
El árbitro indica "Partido Terminado"

### Paso 7: Sistema declara winner
El sistema:
1. Cuenta sets ganados por cada entry
2. Determina winner (más sets ganados)
3. UPDATE match.status = 'FINISHED'
4. INSERT en `community_feed` (MATCH_COMPLETED)

## Postcondiciones
- Match.status = 'FINISHED'
- Trigger `trg_match_completion` ejecuta
- Trigger `trg_advance_bracket` ejecuta

## Excepciones

### E-01: Walkover
- Si un equipo no se presenta, árbitro indica W_O
- Sistema: UPDATE match.status = 'W_O'
