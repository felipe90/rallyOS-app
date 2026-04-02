# SPEC-DB-01: Database Schema - Round Robin Tables (Sport-Agnostic)

## Purpose

Definir el schema de base de datos para soportar el flujo de Round Robin Groups en RallyOS de forma **sport-agnostic**.

> **Nota**: La estructura de tablas es genérica. Las reglas de negocio (límites de grupo, modos de referee, etc.) se configuran en `sports.scoring_config` y se aplican en triggers/RPCs condicionalmente.

---

## Configuration Location

La configuración sport-specific vive en `sports.scoring_config`:

```json
{
  "tournament_format": {
    "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
    "referee_mode": "INTRA_GROUP",
    "loser_referees_winner": true,
    "group_size": { "min": 3, "max": 5 }
  }
}
```

---

## New Tables

### Table: round_robin_groups

Almacena los grupos Round Robin de un torneo.

```sql
CREATE TABLE round_robin_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    name TEXT NOT NULL,  -- 'A', 'B', 'C', etc.
    advancement_count INTEGER DEFAULT 2,  -- Cuántos avanzan a bracket
    status group_status DEFAULT 'PENDING',  -- PENDING, IN_PROGRESS, COMPLETED
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_group_name_per_tournament UNIQUE (tournament_id, name),
    CONSTRAINT advancement_positive CHECK (advancement_count > 0),
    CONSTRAINT name_length CHECK (char_length(name) <= 10)
);

CREATE INDEX idx_rrg_tournament ON round_robin_groups(tournament_id);
```

**Enums:**

```sql
CREATE TYPE group_status AS ENUM ('PENDING', 'IN_PROGRESS', 'COMPLETED');
```

**Notes:**
- `name` típicamente es una letra (A, B, C) pero se permite texto corto
- `advancement_count` default 2, puede variar si el formato lo requiere
- `tournament_id` FK con CASCADE para limpieza automática

---

### Table: group_members

Miembros de un grupo Round Robin.

```sql
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES round_robin_groups(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES persons(id),
    entry_id UUID NOT NULL REFERENCES tournament_entries(id),
    seed INTEGER NOT NULL,  -- 1 = cabeza de grupo, 2, 3, etc.
    status member_status DEFAULT 'ACTIVE',  -- ACTIVE, WALKED_OVER, DISQUALIFIED
    check_in_at TIMESTAMPTZ,  -- NULL si no llegó
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_person_per_tournament UNIQUE (group_id, person_id),
    CONSTRAINT unique_entry_per_group UNIQUE (group_id, entry_id),
    CONSTRAINT seed_positive CHECK (seed > 0),
    CONSTRAINT unique_seed_per_group UNIQUE (group_id, seed)  -- Un solo seed=1, etc.
);

CREATE INDEX idx_gm_group ON group_members(group_id);
CREATE INDEX idx_gm_person ON group_members(person_id);
CREATE INDEX idx_gm_entry ON group_members(entry_id);
```

**Enums:**

```sql
CREATE TYPE member_status AS ENUM ('ACTIVE', 'WALKED_OVER', 'DISQUALIFIED');
```

**Notes:**
- `person_id` uniqueness por tournament se valida vía trigger (no puede estar en dos grupos del mismo torneo)
- `entry_id` link al tournament_entry del jugador
- `seed` determina cabeza de grupo y orden de BYE en scheduling

---

### Table: knockout_brackets

Llave de eliminación generada post-round-robin.

```sql
CREATE TABLE knockout_brackets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    status bracket_status DEFAULT 'PENDING',  -- PENDING, IN_PROGRESS, COMPLETED
    third_place_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT one_bracket_per_tournament UNIQUE (tournament_id)
);

CREATE INDEX idx_kb_tournament ON knockout_brackets(tournament_id);
```

**Enums:**

```sql
CREATE TYPE bracket_status AS ENUM ('PENDING', 'IN_PROGRESS', 'COMPLETED');
```

**Notes:**
- Un torneo puede tener UNO o NINGUN bracket (si es solo round-robin)
- `third_place_enabled` indica si hay match de bronce

---

### Table: bracket_slots

Posiciones individuales en la llave de KO.

```sql
CREATE TABLE bracket_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bracket_id UUID NOT NULL REFERENCES knockout_brackets(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,  -- 1, 2, 3... para seeding inicial
    round INTEGER NOT NULL,  -- 1 = quarters, 2 = semis, 3 = final (o según estructura)
    round_name TEXT,  -- 'Quarterfinals', 'Semifinals', 'Final', 'Bronze'
    entry_id UUID REFERENCES tournament_entries(id),  -- NULL si no ocupado o BYE
    seed_source TEXT,  -- 'group_a_1', 'group_b_2', etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_position_per_bracket UNIQUE (bracket_id, position),
    CONSTRAINT round_positive CHECK (round > 0),
    CONSTRAINT position_positive CHECK (position > 0)
);

CREATE INDEX idx_bs_bracket ON bracket_slots(bracket_id);
CREATE INDEX idx_bs_entry ON bracket_slots(entry_id);
```

**Notes:**
- `round` indica la ronda (1=primera, 2=segunda, etc.)
- `round_name` es descriptivo ('Quarterfinals', 'Semifinals', 'Final', 'Bronze')
- `seed_source` indica de dónde viene el seed para auditoría

---

## Tables to UPDATE

### Update: matches

Agregar columnas para soportar grupos y fase.

```sql
ALTER TABLE matches ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES round_robin_groups(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS bracket_id UUID REFERENCES knockout_brackets(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS phase match_phase DEFAULT 'ROUND_ROBIN';  -- NEW
ALTER TABLE matches ADD COLUMN IF NOT EXISTS round_number INTEGER;  -- NEW: Ronda dentro del grupo/bracket
ALTER TABLE matches ADD COLUMN IF NOT EXISTS next_match_id UUID REFERENCES matches(id);  -- NEW: Próximo del ganador
ALTER TABLE matches ADD COLUMN IF NOT EXISTS loser_assigned_referee UUID REFERENCES auth.users(id);  -- NEW
```

**New Enum:**

```sql
CREATE TYPE match_phase AS ENUM ('ROUND_ROBIN', 'KNOCKOUT', 'BRONZE', 'FINAL');
```

**Notes:**
- `group_id` = NULL significa que no es parte de un grupo RR
- `bracket_id` = NULL significa que no es parte de un bracket KO
- `phase` indica la fase del torneo para este match
- `next_match_id` es CRUCIAL para la loser-as-referee rule
- `loser_assigned_referee` almacena el user_id del perdedor para posible asignación

---

### Update: referee_assignments

Agregar tipo de asignación.

```sql
ALTER TABLE referee_assignments ADD COLUMN IF NOT EXISTS assignment_type assignment_type DEFAULT 'MANUAL';
```

**New Enum:**

```sql
CREATE TYPE assignment_type AS ENUM ('AUTOMATIC', 'MANUAL', 'LOSER_ASSIGNED');
```

**Notes:**
- `AUTOMATIC`: Sistema sugirió basándose en round-robin de arbitraje
- `MANUAL`: Organizador eligió manualmente
- `LOSER_ASSIGNED`: El perdedor del partido anterior fue asignado automáticamente

---

## Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         TOURNAMENTS                               │
│  (existing)                                                      │
└───────────────────────────┬─────────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────┐  ┌──────────────┐  ┌─────────────────┐
│ROUND_ROBIN_GROUPS│  │ MATCHES      │  │KNOCKOUT_BRACKETS│
│                 │  │              │  │                 │
│ - tournament_id │──│ - group_id   │  │ - tournament_id │──┐
│ - name          │  │ - bracket_id │  │                 │  │
│ - status        │  │ - phase      │  └────────┬────────┘  │
└────────┬────────┘  │ - round_num  │           │           │
         │           │ - next_match │           ▼           │
         │           │              │  ┌────────────────┐     │
         ▼           └──────┬───────┘  │ BRACKET_SLOTS  │     │
┌────────────────┐           │          │                │     │
│  GROUP_MEMBERS │           │          │ - bracket_id    │     │
│                │           │          │ - position     │     │
│ - group_id     │───────────┘          │ - round        │     │
│ - person_id    │                      │ - entry_id     │     │
│ - entry_id    │                       └────────────────┘     │
│ - seed         │                                                   │
│ - status       │                      ┌────────────────┐        │
└───────┬────────┘                      │MATCHES         │        │
        │                               │                │        │
        │           ┌──────────────────│ - group_id     │◄───────┘
        │           │                   │ - bracket_id   │
        ▼           ▼                   │ - next_match_id│
   ┌─────────┐ ┌───────────┐            │ - loser_assigned│
   │PERSONS  │ │TOURNAMENT_│            └────────────────┘
   │         │ │ENTRIES    │
   └─────────┘ └───────────┘
```

---

## Indexes for Query Performance

```sql
-- Para encontrar matches disponibles para arbitrar en un grupo
CREATE INDEX idx_matches_group_available 
ON matches(group_id, status) 
WHERE group_id IS NOT NULL AND status IN ('SCHEDULED', 'READY');

-- Para encontrar próximo match del ganador
CREATE INDEX idx_matches_next_match 
ON matches(next_match_id) 
WHERE next_match_id IS NOT NULL;

-- Para contar matches arbitados por persona
CREATE INDEX idx_ref_assignments_user 
ON referee_assignments(user_id);
```

---

## Notes

- Todas las tablas nuevas usan `gen_random_uuid()` como PK por consistencia
- Los timestamps `created_at` y `updated_at` se incluyen para auditoría
- Los constraints de FK usan `ON DELETE CASCADE` para limpieza automática
- Los `CHECK` constraints previenen datos inválidos a nivel de DB
