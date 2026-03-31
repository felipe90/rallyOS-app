# CU-06: Sistema Calcula ELO Automáticamente

## Actor
- Sistema (trigger automático)

## Objetivo
Calcular y registrar cambios de ELO cuando un partido termina

## Trigger
Se ejecuta automáticamente via `trg_match_completion` cuando:
- match.status cambia a 'FINISHED'

## Flujo Principal

### Paso 1: Sistema obtiene datos
El sistema obtiene:
- Winner entry_id → entry_members → person_id
- Loser entry_id → entry_members → person_id
- current_elo de ambos de `athlete_stats`

### Paso 2: Sistema calcula ELO
El sistema aplica fórmula:
```
Expected = 1 / (1 + 10^((Opponent_ELO - My_ELO) / 400))
K = 32 (0-29 matches), 24 (30-99), 16 (100+)
New_ELO = Old_ELO + K * (Actual - Expected)
```
Donde Actual = 1 para winner, 0 para loser

### Paso 3: Sistema registra cambios
Para winner y loser:
1. INSERT en `elo_history`:
   - person_id, sport_id, match_id
   - previous_elo, new_elo, elo_change
   - change_type (MATCH_WIN o MATCH_LOSS)
2. UPDATE `athlete_stats`:
   - current_elo = new_elo
   - matches_played++

### Paso 4: Verificación
Los cambios quedan registrados para auditoría

## Postcondiciones
- elo_history tiene 2 nuevos registros (winner y loser)
- athlete_stats de ambos jugadores actualizado
- ELO del winner subió, del loser bajó
