# CU-07: Ganador Avanza al Siguiente Partido

## Actor
- Sistema (trigger automático)

## Objetivo
Avanzar automáticamente al winner del partido actual al siguiente match en el bracket

## Trigger
Se ejecuta automáticamente via `trg_advance_bracket` cuando:
- match.status cambia a 'FINISHED'
- match.next_match_id IS NOT NULL

## Flujo Principal

### Paso 1: Sistema determina winner
El sistema:
1. Lee sets_json de scores
2. Cuenta sets ganados por entry_a y entry_b
3. Establece winner_entry_id

### Paso 2: Sistema avanza bracket
El sistema:
1. Lee next_match_id del match actual
2. Verifica si next_match tiene entry_a o entry_b vacío
3. Coloca winner en el slot vacío:
   - Si entry_a_id IS NULL → entry_a_id = winner_entry_id
   - Si entry_b_id IS NULL → entry_b_id = winner_entry_id

### Paso 3: Sistema verifica si next_match está completo
Si ambos entry_a_id y entry_b_id tienen valores:
- UPDATE next_match.status = 'SCHEDULED'

### Paso 4: Caso Final
Si NO hay next_match_id (es la final):
- Tournament está por terminar
- No se ejecuta avance

## Postcondiciones
- Winner está ubicado en el siguiente match
- El siguiente match puede estar listo para jugar

## Ejemplo

```
Semi-Final 1: Player A vs Player B → Player A gana
  → Player A avanza a Final (entry_a o entry_b de Final)

Semi-Final 2: Player C vs Player D → Player C gana  
  → Player C avanza a Final

Final: Player A vs Player C
```
