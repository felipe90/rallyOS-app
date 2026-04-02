# SPEC-DOM-02: Domain Model - Aggregates & Invariants

## Purpose

Definir los aggregates (grupos de entidades que se modifican juntas) y sus invariantes de negocio para el flujo TT.

## Aggregates

### Aggregate: Tournament Aggregate

**Raíz**: `Tournament`

**Entidades contenidas:**
- Tournament (raíz)
- RoundRobinGroup (Value Object contenido)
- GroupMember (Value Object contenido)
- KnockoutBracket (Value Object contenido)
- BracketSlot (Value Object contenido)

**Boundaries:**
- Todo lo que pertenece a un torneo vive dentro del aggregate
- Los members, groups, bracket no existen fuera de un torneo
- Las transiciones de estado del torneo afectan a todos los children

**Invariantes del Aggregate:**

1. **Tournament Status Transition**
   ```
   DRAFT → REGISTRATION → PRE_TOURNAMENT → CHECK_IN → LIVE → COMPLETED
   ```
   - NO se puede saltar estados
   - NO se puede volver atrás excepto a SUSPENDED (emergencia)
   - PRE_TOURNAMENT: requiere que haya entries registrados

2. **Group Uniqueness**
   - Un person_id PUEDE estar en máximo un RoundRobinGroup por torneo
   - Un person_id puede estar en múltiples grupos de diferentes torneos

3. **Entry Consistency**
   - Cada GroupMember DEBE tener un entry_id válido en tournament_entries
   - Si se cancela un entry, el GroupMember associated debe marcarse accordingly

---

### Aggregate: RoundRobinGroup Aggregate

**Raíz**: `RoundRobinGroup`

**Entidades contenidas:**
- RoundRobinGroup (raíz)
- GroupMember (Value Object)
- Match (Value Object, generados automáticamente)

**Boundaries:**
- Los matches de un grupo solo existen dentro de ese grupo
- El referee assignment para matches del grupo DEBE venir de members del mismo grupo

**Invariantes del Aggregate:**

1. **Member Count Constraint**
   ```
   3 ≤ |members| ≤ 5
   ```
   - Si se intenta agregar un 6to miembro, el sistema RECHAZA
   - Si se intenta remover y queda < 3, el sistema WARN pero PERMITE (se juegan igual)

2. **Round Robin Completeness**
   - El número de matches generados DEBE ser: n × (n-1) / 2
   - No puede haber matches duplicados
   - Cada member debe jugar contra TODOS los demás

3. **Seeding Constraint**
   - El seed=1 (cabeza de grupo) NO puede estar en el mismo grupo que otro seed=1
   - Si hay 4 grupos, debe haber 4 semillas differentes como heads

4. **Group Completion**
   - El grupo alcanza status = COMPLETED cuando TODOS los matches tienen status FINISHED o WALKED_OVER
   - La clasificación se calcula automáticamente al completar

---

### Aggregate: Match Aggregate

**Raíz**: `Match`

**Entidades contenidas:**
- Match (raíz)
- Score (Value Object)
- RefereeAssignment (Entity, única por match)

**Boundaries:**
- Un match no puede existir sin un grupo o bracket padre
- El referee assignment está tightly coupled al match

**Invariantes del Aggregate:**

1. **Player Constraint**
   - `entry_a_id ≠ entry_b_id` (siempre)
   - Si uno es NULL → el otro gana por BYE
   - Un person NO puede jugar contra sí mismo en ningún escenario

2. **Referee Constraint (configurable por referee_mode)**
   ```
   SI referee_mode = 'INTRA_GROUP' ENTONCES
     referee.person_id ∈ group.members.person_id
     referee.person_id ≠ match.entry_a.person_id
     referee.person_id ≠ match.entry_b.person_id
   
   SI referee_mode = 'NONE' ENTONCES
     NO hay referee assignment
   
   SI referee_mode = 'EXTERNAL' ENTONCES
     referee.person_id ∉ any_group (referee externo)
   ```
   > **Sport-Agnostic**: Las reglas de referee dependen de `referee_mode`, no hardcodeadas.

3. **Loser-as-Referee Constraint**
   ```
   SI loser_referees_winner = true ENTONCES
     El perdedor puede ser sugerido como referee del ganador
     SOLO SI referee_mode = 'INTRA_GROUP'
   ```
   > **Sport-Agnostic**: Esta regla SOLO aplica si `loser_referees_winner = true` en config. Default: false.

4. **Score Validity (configurable por sport)**
   ```
   Las reglas de score varían por sport:
   - TT: win by 2, deuce at 10
   - Padel: golden point, win by 2
   - Pickleball: win by 2, no deuce
   
   Las reglas se leen de scoring_config, no hardcodeadas.
   ```

5. **Match Completion**
   - Match status = FINISHED cuando se alcanza el número de sets para ganar
   - El winner se determina automáticamente del score
   - Las reglas de sets (best_of) vienen de scoring_config

---

### Aggregate: Loser-as-Referee Tracking

**Este es un aggregate especial** que cruza múltiples matches.

**Raíz**: No tiene raíz simple — es un proceso que involucra:
- Match actual (donde alguien pierde)
- Match siguiente del GANADOR
- La persona que perdió

**Entidades involucradas:**
- Match (A) — donde se perdió
- Match (B) — próximo del ganador
- Person (perdedor) — candidato a referee
- RefereeAssignment — la asignación propuesta

**Invariantes:**

1. **The Loser Rule**
   ```
   IF match_A.winner = entry_a
   THEN match_B.referee_suggestion = entry_b.person_id
   ```
   - El perdedor DEBE ser sugerido como referee del próximo partido del ganador
   - El organizador PUEDE aceptar o rechazar la sugerencia

2. **Cross-Group Constraint**
   ```
   IF match_B.group_id ≠ match_A.group_id
   THEN perdedor NO puede ser referee (no pertenece al grupo B)
   THEN fallback: buscar cualquier voluntario disponible
   ```
   - Si el próximo partido es de diferente grupo, el perdedor no puede arbitrar
   - Se necesita fallback a otros rules

3. **Final Match Exception**
   - En la FINAL no hay próximo partido
   - El perdedor NO se asigna como referee
   - El organizador elige referee manualmente

4. **Bronze Match Exception**
   - El perdedor de semifinales NO es referee del bronce
   - El bronce tiene su propio referee assignment flow

---

## Business Rules Summary

| Regla | Ámbito | Enforcement |
|-------|--------|-------------|
| 3-5 jugadores por grupo | Group | DB CHECK |
| Un jugador = un grupo | Tournament | DB TRIGGER |
| Seeds únicos como heads | Group Seeding | RPC validation |
| Referee del mismo grupo | Match (RR) | RPC + RLS |
| Win by 2 en TT | Score | TRIGGER validate_score |
| Perdedor → próximo referee | Match Process | RPC on match finish |
| N*(N-1)/2 matches por grupo | Group | RPC generation |
| Estados válidos de torneo | Tournament | RPC + application logic |

---

## Notes

- **Shadow Profile Exception**: Personas sin user_id (shadow profiles) NO pueden ser referees porque necesitan user_id para la asignación
- **Offline Score Entry**: Los scores se registran MANUAL por el organizador después de que los árbitros los escriben en papel
- **BYE in Brackets**: Si un bracket tiene número non-power-of-2, los primeros slots en order de seed reciben BYE al primer round
