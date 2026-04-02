# SPEC-DOM-01: Domain Model - Entities

## Purpose

Definir las entidades de dominio para el flujo de torneos de Table Tennis en RallyOS, sin pensar aún en implementación de DB.

## Entities

### Tournament (Torneo)

El agregado raíz que contiene todo el contexto del torneo.

**Propiedades:**
- `id`: Identificador único
- `sport_id`: Deporte (siempre Table Tennis para este flujo)
- `name`: Nombre del torneo
- `status`: Estado actual (DRAFT → REGISTRATION → PRE_TOURNAMENT → CHECK_IN → LIVE → COMPLETED)
- `registration_mode`: ONLINE (no external links)
- `categories`: Lista de categorías (opcional para TT simple)
- `groups`: Lista de Round Robin Groups
- `bracket`: Llave de eliminación (generada post-groups)
- `created_at`: Timestamp de creación

**Invariantes:**
- El torneo DEBE tener exactamente un sport_id
- El status DEBE seguir la secuencia válida de transiciones
- Cuando status = LIVE, DEBE existir al menos un grupo o bracket activo

---

### RoundRobinGroup (Grupo Round Robin)

Entidad que representa un grupo de N jugadores que juegan round-robin.

> **Nota de Sport-Agnosticidad**: El tamaño del grupo (min/max) se define en `tournament_format.group_size` del sport. Por defecto: 3-5 (TT), pero configurable.

**Propiedades:**
- `id`: Identificador único
- `tournament_id`: FK al torneo padre
- `name`: Identificador legible (A, B, C, etc.)
- `members`: Lista de GroupMember
- `matches`: Lista de Match (generados automáticamente)
- `status`: PENDING → IN_PROGRESS → COMPLETED
- `advancement_count`: Cuántos jugadores avanzan a bracket (default: 2)
- `created_at`: Timestamp de creación

**Invariantes:**
- El grupo DEBE contener entre `group_size.min` y `group_size.max` miembros (configurable)
- Todos los miembros DEBEN pertenecer al mismo tournament_id
- El nombre DEBE ser único dentro del torneo
- **Solo se crea si `tournament_format.structure` incluye grupos**

---

### GroupMember (Miembro de Grupo)

Entidad que representa la pertenencia de un jugador a un grupo.

**Propiedades:**
- `id`: Identificador único
- `group_id`: FK al grupo padre
- `person_id`: FK a la persona
- `seed`: Posición de siembra (1 = cabeza de grupo)
- `entry_id`: FK al tournament_entry del jugador
- `status`: ACTIVE, WALKED_OVER, DISQUALIFIED
- `check_in_at`: Timestamp de check-in (puede ser null si no llegó)

**Invariantes:**
- Un person_id PUEDE estar en máximo un grupo por torneo
- El seed DEBE ser único dentro del grupo
- Si status = WALKED_OVER, todos sus partidos se marcan W/O

---

### Match (Partido)

Entidad que representa un partido individual.

**Propiedades:**
- `id`: Identificador único
- `group_id`: FK al grupo (null si es bracket KO)
- `bracket_id`: FK al bracket (null si es round-robin)
- `entry_a_id`: FK al primer entry (o null para BYE)
- `entry_b_id`: FK al segundo entry (o null para BYE)
- `status`: SCHEDULED, READY, LIVE, FINISHED, WALKED_OVER, SUSPENDED
- `round`: Número de ronda (para scheduling)
- `court`: Identificador de cancha
- `referee`: Persona asignada como árbitro
- `score`: Score actual (points_a, points_b, sets)
- `phase`: ROUND_ROBIN | KNOCKOUT | BRONZE | FINAL
- `next_match_of_winner`: Referencia al próximo partido del ganador

**Invariantes:**
- entry_a_id y entry_b_id NO PUEDEN ser el mismo
- Si entry_a_id = NULL o entry_b_id = NULL, es un BYE
- El referee DEBE ser del MISMO grupo que los jugadores (para fase ROUND_ROBIN)
- Para fase KNOCKOUT: el referee PUEDE ser cualquier persona del bracket o perdedor del partido anterior

---

### RefereeAssignment (Asignación de Árbitro)

Entidad que representa la asignación de un árbitro a un partido.

**Propiedades:**
- `id`: Identificador único
- `match_id`: FK al partido
- `user_id`: FK al usuario que arbitra
- `assignment_type`: AUTOMATIC | MANUAL | LOSER_ASSIGNED
- `assigned_by`: FK al usuario que hizo la asignación (null si automático)
- `is_confirmed`: Boolean (organizador confirmó)
- `created_at`: Timestamp

**assignment_type values:**
- `AUTOMATIC`: Sistema sugirió basándose en round-robin de arbitraje
- `MANUAL`: Organizador eligió manualmente
- `LOSER_ASSIGNED`: El perdedor del partido anterior fue asignado

**Invariantes:**
- Solo puede existir UNA asignación activa por partido
- El user_id NO PUEDE ser igual a entry_a_id ni entry_b_id
- Para fase ROUND_ROBIN: el user_id DEBE pertenecer al MISMO grupo

---

### Score (Resultado)

Entidad que representa el score de un partido.

**Propiedades:**
- `id`: Identificador único
- `match_id`: FK al partido
- `points_a`: Puntos del jugador A
- `points_b`: Puntos del jugador B
- `sets`: Lista de sets jugados
- `winner`: Entry ID del ganador (derived)
- `entry_method`: MANUAL (para TT: scores escritos a mano)
- `recorded_at`: Timestamp de registro
- `recorded_by`: FK al usuario que registró

**Invariantes:**
- El score DEBE cumplir las reglas de Table Tennis (win by 2, hasta 11 puntos)
- Si un set está en 10-10, continue hasta diferencia de 2
- El match status DEBE ser FINISHED cuando se registra score final

---

### KnockoutBracket (Llave de Eliminación)

Entidad que representa la llave de KO generada post-round-robin.

**Propiedades:**
- `id`: Identificador único
- `tournament_id`: FK al torneo
- `groups`: Lista de grupos que alimentan esta llave
- `slots`: Lista de BracketSlot
- `status`: PENDING → IN_PROGRESS → COMPLETED
- `created_at`: Timestamp

**Invariantes:**
- Los slots DEBEN estar correctamente seeded según resultados de grupos
- El bracket DEBE seguir estructura de power-of-2 (si no, bye slots)

---

### BracketSlot (Posición en Llave)

**Propiedades:**
- `id`: Identificador único
- `bracket_id`: FK al bracket padre
- `position`: Posición en la llave (1, 2, 3...)
- `round`: Ronda (Quarter, Semi, Final)
- `entry_id`: FK al entry que ocupa esta posición
- `seed_source`: De qué grupo/victoria viene este seed

---

## Relationships

```
Tournament (1) ──────< RoundRobinGroup (N)
                           │
                           │ 1:N
                           ▼
                    GroupMember (N)
                           │
                           │ N:1
                           ▼
                      Person (1)

RoundRobinGroup (1) ───< Match (N)
      │
      │ N:1 (cada match puede tener un next_match)
      ▼
   Match (1) ────< RefereeAssignment (1)
                           │
                           ▼
                        Person (1)

Tournament (1) ────< KnockoutBracket (1)
                           │
                           ▼
                    BracketSlot (N)
```

---

## Notes

- **Shadow Profiles**: Personas sin user_id pueden participar pero NO pueden arbitrar
- **BYE Handling**: Un BYE es un slot vacío, no un entry_id = null significa forfeit automático
- **Phase Transitions**: ROUND_ROBIN → KNOCKOUT requiere que todos los grupos estén COMPLETED
