# SPEC-DOM-03: Domain Model - Business Rules (Sport-Agnostic)

## Purpose

Detallar las reglas de negocio de RallyOS que son **configurables por sport/tournament**.

> **Nota**: Este documento reemplaza las reglas hardcodeadas de TT con configuración sport-agnostic.

---

## Rule 1: Group Creation (Configurable)

### BR-GROUP-001: Límite de Miembros (Configurable)

**Descripción**: Un grupo Round Robin DEBE contener entre `group_size.min` y `group_size.max` jugadores.

> **Sport-Agnostic**: Los valores vienen de `tournament_format.group_size` en el config del sport.

**Valores por defecto (TT)**:
```json
{ "min": 3, "max": 5 }
```

**Valores ejemplo para otros sports**:
| Sport | min | max |
|-------|-----|-----|
| Table Tennis | 3 | 5 |
| Badminton | 4 | 6 |
| Padel Mexicano | 3 | 4 |

**Comportamiento**:
- Intentos de agregar > `max` jugadores → RECHAZAR con error
- Intentos de quedar < `min` jugadores → WARN pero PERMITIR

**Escenarios**:

| Scenario | Input | Config | Result |
|----------|-------|--------|--------|
| Crear grupo con 3 | [P1, P2, P3] | min=3 | ✅ ACEPTADO |
| Crear grupo con 4 | [P1..P4] | min=3, max=5 | ✅ ACEPTADO |
| Crear grupo con 6 | [P1..P6] | max=5 | ❌ RECHAZADO "Máximo 5 jugadores" |
| Grupo con 4, quitar 2 | [P1, P2] | min=3 | ⚠️ WARN |

---

## Rule 2: Seeding - Heads of Groups

### BR-SEED-001: Separación de Seeds

**Descripción**: Los cabezas de grupo (seed=1) DEBEN estar en grupos diferentes.

**Comportamiento**:
- Si hay N grupos, debe haber N seeds diferentes como heads
- Seed 1 del Grupo A ≠ Seed 1 del Grupo B

**Escenarios**:

| Scenario | Result |
|----------|--------|
| 4 grupos, sembrar top 4 ELO como heads | Cada uno en grupo diferente ✅ |
| Intentar poner seed 1 en dos grupos | ❌ RECHAZADO "Head ya asignado a otro grupo" |
| Sin ELO disponible | Se permite mismo seed en diferentes grupos (shadow profiles) |

### BR-SEED-002: Seed Order dentro del Grupo

**Descripción**: Los seeds dentro de un grupo se ordenan de mayor a menor.

**Comportamiento**:
- Seed 1 = mejor jugador
- Seed 2 = segundo mejor
- Seed 3 = tercero...
- Los BYEs se dan a los seeds más bajos

---

## Rule 3: Round Robin Scheduling

### BR-RR-001: Matches Generados

**Descripción**: Para N jugadores, se generan exactamente N×(N-1)/2 matches.

**Fórmula**: `total_matches = n! / (2! × (n-2)!) = n × (n-1) / 2`

**Tabla de referencia**:

| Jugadores | Matches | Rondas (si 1 match/ronda) |
|-----------|---------|---------------------------|
| 3 | 3 | 3 |
| 4 | 6 | 3 (2 matches por ronda) |
| 5 | 10 | 5 (2 matches por ronda) |

### BR-RR-002: Scheduling Circular

**Descripción**: El sistema DEBE generar schedule usando algoritmo round-robin circular.

**Para 4 jugadores (P1, P2, P3, P4)**:

```
Ronda 1: P1 vs P2, P3 vs P4 (o P3 BYE)
Ronda 2: P1 vs P3, P2 vs P4 (o P2 BYE)
Ronda 3: P1 vs P4, P2 vs P3 (o P1 BYE)
```

**Para 5 jugadores (BYE rotativo)**:

```
Ronda 1: P1 vs P2, P3 vs P4 (P5 BYE)
Ronda 2: P1 vs P3, P2 vs P5 (P4 BYE)
Ronda 3: P1 vs P4, P3 vs P5 (P2 BYE)
Ronda 4: P1 vs P5, P2 vs P4 (P3 BYE)
Ronda 5: P2 vs P3, P4 vs P5 (P1 BYE)
```

---

## Rule 4: Classification / Standings

### BR-CLASS-001: Puntos por Resultado

**Descripción**: Los puntos se asignan por partido completado:

| Resultado | Puntos |
|-----------|--------|
| Victoria | 3 pts |
| Empate | 1 pt cada uno |
| Derrota | 0 pts |
| Walkover | 0 pts |

### BR-CLASS-002: Criterios de Desempate

**Descripción**: Si hay empate en puntos, usar en orden:

1. **Head-to-Head**: Resultado entre los empatados
2. **Difference de puntos**: Mayor diferencia de puntos a favor - en contra
3. **Puntos a favor**: Mayor cantidad de puntos ganados
4. **Puntos en contra**: Menor cantidad de puntos en contra
5. **Sorteo**: Si todo empata, decisión por suerte

### BR-CLASS-003: Cálculo de Puntos

**Descripción**: "Puntos" = suma de puntos de todos los sets ganados - puntos de sets perdidos.

**Ejemplo**:
```
Jugador A gana: 11-8, 8-11, 11-5
Jugador B: 11-9, 5-11, 7-11

A: (11-8) + (8-11) + (11-5) = 3 + (-3) + 6 = 6 puntos de diferencia
B: (8-11) + (11-8) + (5-11) = -3 + 3 + (-6) = -6 puntos de diferencia
```

---

## Rule 5: Referee - Configurable por Sport

> **Sport-Agnostic**: Las reglas de referee dependen de `referee_mode` en `tournament_format`.

### BR-REF-001: Pool de Referees (Depende de referee_mode)

**Descripción**: Según `referee_mode`, diferentes reglas aplican:

| referee_mode | Pool de Referees |
|--------------|-----------------|
| `NONE` | No hay referees (Americano) |
| `INTRA_GROUP` | Solo compañeros del MISMO grupo |
| `ROTATING` | Compañeros que no están jugando + rotación |
| `EXTERNAL` | Referees externos al tournament |
| `ORGANIZER` | Solo el organizador |

**Para INTRA_GROUP (TT)**:
```
validos = [A3, A4, A5] ∩ checked_in ∩ has_user_id
```

**Reglas de exclusión (INTRA_GROUP)**:
- ❌ No puede ser A1 (jugando)
- ❌ No puede ser A2 (jugando)
- ❌ No puede ser de Grupo B (diferente grupo)
- ❌ No puede ser shadow profile (sin user_id)

### BR-REF-002: Prioridad de BYE

**Descripción**: Si un jugador tiene BYE en una ronda, tiene PRIORIDAD como referee.

**Comportamiento** (solo si `referee_mode = 'INTRA_GROUP'` o `'ROTATING'`):
```
SI jugador.tiene_BYE_en_ronda_actual
ENTONCES sugerencia_referee = ese_jugador
SINO
  sugerencia_referee = menos_arbitrajes_recientes
```

### BR-REF-003: Round Robin de Arbitraje

**Descripción**: El sistema DEBE balancear la cantidad de partidos arbitrado por persona.

**Meta**: Cada jugador arbitra aproximadamente ceil(matches_del_grupo / jugadores)

| Grupo | Jugadores | Matches | Arbitrajes por persona |
|-------|-----------|---------|------------------------|
| 3 | 3 | 3 | 1 |
| 4 | 4 | 6 | 1-2 |
| 5 | 5 | 10 | 2 |

---

## Rule 6: The Loser Referees the Winner (Configurable)

> **Sport-Agnostic**: Esta regla SOLO aplica si `loser_referees_winner = true`.

### BR-LOSER-001: Asignación Automática Post-Match

**Descripción**: Al terminar un partido, el PERDEDOR es sugerido como referee del PRÓXIMO partido del GANADOR.

**Solo si**: `loser_referees_winner = true` Y `referee_mode = 'INTRA_GROUP'`

**Trigger**: `match.status = FINISHED`

**Comportamiento**:
```
SI loser_referees_winner = true
ENTONCES
  match_actual.winner = A
  proximo_match = match_actual.next_match_of_winner
  perdedor = match_actual.loser
  
  SI proximo_match ≠ NULL
    sugerencia = perdedor
    tipo = LOSER_ASSIGNED
```

### BR-LOSER-002: Cross-Group Exception

**Descripción**: Si el próximo partido del ganador es de DIFERENTE GRUPO, el perdedor NO puede arbitrar.

**Comportamiento**:
```
SI proximo_match.group_id ≠ match_actual.group_id
ENTONCES
  sugerencia = NULL (no asignar automático)
  tipo = MANUAL (organizador elige)
  mensaje = "Próximo partido es de diferente grupo, elegir referee manualmente"
```

### BR-LOSER-003: Final Match Exception

**Descripción**: La FINAL no tiene próximo partido, por lo tanto NO hay asignación de loser como referee.

**Comportamiento**:
```
SI match.phase = FINAL
ENTONCES
  sugerencia = NULL
  mensaje = "Final no requiere assignment de perdedor"
  organizador.elige_referee_final()
```

### BR-LOSER-004: Bronze Match Exception

**Descripción**: El perdedor de semifinales NO es referee del bronce.

**Comportamiento**:
```
SI match.phase = BRONZE
ENTONCES
  // No aplica loser rule del todo
  // El bronce tiene su propia lógica de referee
```

### BR-LOSER-005: Configuración por Sport

| Sport | loser_referees_winner | referee_mode |
|-------|----------------------|-------------|
| Table Tennis | true | INTRA_GROUP |
| Padel Mexicano | false | ROTATING |
| Badminton | false | EXTERNAL |
| Padel Americano | N/A | NONE |

---

## Rule 7: Manual Score Entry

### BR-SCORE-001: Entrada Manual Post-Evento

**Descripción**: En TT amateur, los scores se escriben en papel durante los partidos y luego se digitalizan.

**Flujo**:
1. Árbitro escribe score en papel
2. Organizador revisa paper score
3. Organizador ingresa score en sistema
4. Sistema valida score contra reglas TT

### BR-SCORE-002: Validación de Score TT

**Descripción**: El score DEBE cumplir las reglas de Table Tennis:

```
SET VÁLIDO SI:
  (points < 11) AND (|points_a - points_b| = 1)
  O
  (points_a = 11 OR points_b = 11) AND (|points_a - points_b| ≥ 2)
  O
  (points_a ≥ 12 OR points_b ≥ 12) AND (|points_a - points_b| = 2)
```

**Casos válidos**:
- 11-9 ✅ (win by 2)
- 12-10 ✅ (deuce extension)
- 15-13 ✅ (extended deuce)
- 10-12 ❌ (perdedor llegó a 11 primero)
- 11-7 ✅
- 11-8 ❌ (no win by 2)

### BR-SCORE-003: Set Winner Calculation

**Descripción**: Para best-of-5 (TT), el primer en ganar 3 sets gana el match.

**Match válido si**:
- Match es best_of_sets
- Jugador gana ceil(best_of_sets / 2) sets

| best_of | Sets para ganar | Escenarios |
|---------|-----------------|------------|
| 3 | 2 | 2-0, 2-1 |
| 5 | 3 | 3-0, 3-1, 3-2 |

---

## Rule 8: Group to Bracket Transition

### BR-BRACKET-001: Generación Post-Group

**Descripción**: El bracket de KO se genera cuando TODOS los grupos están COMPLETED.

**Trigger**: `all_groups.status = COMPLETED`

**Comportamiento**:
```
SI todos_los_grupos.completados
ENTONCES generar_bracket()
  - top N de cada grupo = clasificados
  - seeding según posición en grupo
  - slots准备好 para KO
```

### BR-BRACKET-002: Seeding desde Grupos

**Descripción**: La posición en el bracket se determina por:
1. Posición en el grupo (1ro, 2do, etc.)
2. ELO o ranking del jugador

**Ejemplo con 4 grupos de 4 jugadores (top 2 avanzan)**:

```
Grupo A: 1ro=A1, 2do=A2
Grupo B: 1ro=B1, 2do=B2
Grupo C: 1ro=C1, 2do=C2
Grupo D: 1ro=D1, 2do=D2

Bracket seeding sugerido:
- 1er línea: A1 (mejor grupo/seed)
- 2da línea: B1
- 3ra línea: C1
- 4ta línea: D1
- 5ta línea: A2
- 6ta línea: B2
...
```

---

## Rule 9: Walkover (W/O)

### BR-WO-001: Jugador No Se Presenta

**Descripción**: Si un jugador no se presenta, pierde todos sus partidos.

**Comportamiento**:
```
SI member.status = WALKED_OVER
ENTONCES
  - Todos sus matches = W/O
  - Oponente gana por default
  - 0 puntos para W/O
  - No afecta clasificación de others
```

### BR-WO-002: Grupo con W/O

**Descripción**: Un grupo puede jugar con menos de 3 miembros activos si los others están W/O.

**Comportamiento**:
```
SI active_members < 3
ENTONCES
  - Se juegan los partidos posibles
  - Los others reciben W/O en partidos no jugados
  - Si solo queda 1, torneo no puede continuar (needs manual decision)
```

---

## Notes

- Todas estas reglas están orientadas a Table Tennis pero el sistema DEBERÍA ser extensible para otros deportes de mesa
- La validación de score (Rule 7.2) está implementada en el trigger `trg_validate_score`
- La loser rule (Rule 6) requiere tracking del `next_match_of_winner` en el match
