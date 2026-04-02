# Design: Staff & Player-As-Referee System

## Technical Approach

Implementar sistema híbrido de staff con soporte para:
1. Asignación automática + invitación con accept/reject
2. Jugadores checked-in pueden arbitrar matches donde no juegan
3. Sugerencias automáticas con round-robin y override manual

**Specs referenciadas**: SPEC-010, SPEC-011, SPEC-SEC

## Architecture Decisions

### Decision 1: Modo de asignación por invitación

**Choice**: Campo `invite_mode BOOLEAN DEFAULT TRUE` en tournament_staff
**Alternatives**: Tabla separada de invitaciones
**Rationale**: Más simple, permite saber de un vistazo si fue invitación o asignación directa

### Decision 2: Vista vs RPC para available_referees

**Choice**: Vista `available_referees(match_id)` + función helper
**Alternatives**: Solo RPC con filtros embebidos
**Rationale**: Permite filtrar en cliente y JOINs más limpios; función helper para validaciones

### Decision 3: referee_assignments como auditoría

**Choice**: Tabla `referee_assignments` (no modifica `matches.referee_id`)
**Alternatives**: Solo columna en matches
**Rationale**: Mantiene historial para estadísticas sin duplicar datos

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUJO DE STAFF                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Organizer                                                     │
│    │                                                           │
│    ├── assign_staff(user_id, role, mode='direct')              │
│    │     │                                                     │
│    │     └──→ INSERT tournament_staff (status=ACTIVE)          │
│    │                                                           │
│    └── invite_staff(user_id, role)                             │
│          │                                                     │
│          └──→ INSERT tournament_staff (status=PENDING)          │
│                                                               │
│  Invitado                                                      │
│    │                                                           │
│    └── accept_invitation(tournament_id)                        │
│          │                                                     │
│          └──→ UPDATE tournament_staff (status=ACTIVE)          │
│                                                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    FLUJO PLAYER-AS-REFEREE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Jugador Checkeado                                              │
│    │                                                           │
│    └── toggle_referee_volunteer(true)                          │
│          │                                                     │
│          ├──→ INSERT referee_volunteers (is_active=true)       │
│          └──→ INSERT tournament_staff (PLAYER_REFEREE, ACTIVE) │
│                                                               │
│  generate_referee_suggestions(category_id)                      │
│    │                                                           │
│    ├──→ Query available_referees para cada match              │
│    ├──→ Round-robin por matches_refereed ASC                  │
│    └──→ INSERT referee_assignments (suggested=true)           │
│                                                               │
│  Organizer                                                     │
│    │                                                           │
│    └── confirm_referee_assignment(match_id)                    │
│          │                                                     │
│          ├──→ UPDATE matches.referee_id                        │
│          └──→ UPDATE referee_assignments (suggested=false)    │
│                                                               │
└─────────────────────────────────────────────────────────────────┘
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000026_staff_enhanced.sql` | Create | Schema enhancements: status enum, mode, RLS updates |
| `supabase/migrations/00000000000027_referee_pool.sql` | Create | referee_volunteers, referee_assignments, view |
| `supabase/migrations/00000000000028_staff_rpcs.sql` | Create | RPCs: assign_staff, invite_staff, accept/reject, toggle_volunteer, generate_suggestions |
| `supabase/migrations/00000000000029_staff_rls_update.sql` | Create | RLS policies actualizadas |
| `supabase/seed_v2.sql` | Create | Seed con 16 dummy users + 2 categorías |
| `supabase/migrations/00000000000001_security_policies.sql` | Modify | Actualizar RLS de matches y scores |

## Schema Changes

### 1. ENUMs Nuevos

```sql
-- staff_status
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_status') THEN
        CREATE TYPE staff_status AS ENUM ('PENDING', 'ACTIVE', 'REJECTED', 'REVOKED');
    END IF;
END $$;
```

### 2. ALTER tournament_staff

```sql
ALTER TABLE tournament_staff 
ADD COLUMN IF NOT EXISTS status staff_status DEFAULT 'ACTIVE',
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS invite_mode BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
```

### 3. Tabla referee_volunteers

```sql
CREATE TABLE referee_volunteers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tournament_id, person_id)
);
```

### 4. Tabla referee_assignments

```sql
CREATE TABLE referee_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id),
    is_suggested BOOLEAN DEFAULT FALSE,
    is_confirmed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(match_id)
);
```

### 5. Vista available_referees

```sql
CREATE OR REPLACE VIEW available_referees AS
SELECT DISTINCT
    m.id AS match_id,
    p.user_id,
    p.id AS person_id,
    te.tournament_id
FROM matches m
JOIN categories c ON c.id = m.category_id
JOIN tournaments t ON t.id = c.tournament_id
JOIN tournament_entries te ON te.category_id = c.id
JOIN entry_members em ON em.entry_id = te.id
JOIN persons p ON p.id = em.person_id
WHERE te.checked_in_at IS NOT NULL
  AND p.user_id IS NOT NULL
  AND p.user_id != ALL(ARRAY[
      SELECT p2.user_id
      FROM matches m2
      JOIN categories c2 ON c2.id = m2.category_id
      JOIN tournament_entries te2 ON te2.category_id = c2.id
      JOIN entry_members em2 ON em2.entry_id = te2.id
      JOIN persons p2 ON p2.id = em2.person_id
      WHERE m2.id = m.id
  ])
  AND NOT EXISTS (
      SELECT 1 FROM referee_assignments ra
      WHERE ra.match_id = m.id AND ra.is_confirmed = TRUE
  );
```

## RPCs Principales

### assign_staff

```sql
CREATE OR REPLACE FUNCTION assign_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT,
    p_invite_mode BOOLEAN DEFAULT FALSE
) RETURNS tournament_staff AS $$
DECLARE
    v_staff tournament_staff;
BEGIN
    -- Validar que es ORGANIZER
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = p_tournament_id
          AND user_id = auth.uid()
          AND role = 'ORGANIZER'
          AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can assign staff';
    END IF;

    -- Validar rol
    IF p_role NOT IN ('EXTERNAL_REFEREE', 'PLAYER_REFEREE') THEN
        RAISE EXCEPTION 'Invalid role. Must be EXTERNAL_REFEREE or PLAYER_REFEREE';
    END IF;

    -- Insertar o actualizar
    INSERT INTO tournament_staff (tournament_id, user_id, role, status, invited_by, invite_mode)
    VALUES (p_tournament_id, p_user_id, p_role, 
            CASE WHEN p_invite_mode THEN 'PENDING' ELSE 'ACTIVE' END,
            auth.uid(), p_invite_mode)
    ON CONFLICT (tournament_id, user_id) 
    DO UPDATE SET role = p_role, status = CASE WHEN p_invite_mode THEN 'PENDING' ELSE 'ACTIVE' END,
                  invited_by = auth.uid(), invite_mode = p_invite_mode
    RETURNING * INTO v_staff;
    
    RETURN v_staff;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### toggle_referee_volunteer

```sql
CREATE OR REPLACE FUNCTION toggle_referee_volunteer(
    p_tournament_id UUID,
    p_is_active BOOLEAN
) RETURNS VOID AS $$
DECLARE
    v_person_id UUID;
    v_user_id UUID;
    v_is_checked_in BOOLEAN;
BEGIN
    -- Obtener person del usuario actual
    SELECT id, user_id INTO v_person_id, v_user_id
    FROM persons WHERE user_id = auth.uid();
    
    IF v_person_id IS NULL THEN
        RAISE EXCEPTION 'User does not have a linked person profile';
    END IF;

    -- Verificar check-in
    SELECT EXISTS (
        SELECT 1 FROM tournament_entries te
        WHERE te.tournament_id = p_tournament_id
          AND EXISTS (SELECT 1 FROM entry_members em WHERE em.entry_id = te.id AND em.person_id = v_person_id)
          AND te.checked_in_at IS NOT NULL
    ) INTO v_is_checked_in;
    
    IF NOT v_is_checked_in THEN
        RAISE EXCEPTION 'Must be checked-in to volunteer as referee';
    END IF;

    IF p_is_active THEN
        -- Crear voluntario
        INSERT INTO referee_volunteers (tournament_id, person_id, user_id, is_active)
        VALUES (p_tournament_id, v_person_id, v_user_id, TRUE)
        ON CONFLICT (tournament_id, person_id) DO UPDATE SET is_active = TRUE, updated_at = NOW();
        
        -- Crear/actualizar staff
        INSERT INTO tournament_staff (tournament_id, user_id, role, status)
        VALUES (p_tournament_id, v_user_id, 'PLAYER_REFEREE', 'ACTIVE')
        ON CONFLICT (tournament_id, user_id) 
        DO UPDATE SET role = 'PLAYER_REFEREE', status = 'ACTIVE';
    ELSE
        -- Desactivar voluntario
        UPDATE referee_volunteers SET is_active = FALSE WHERE tournament_id = p_tournament_id AND person_id = v_person_id;
        UPDATE tournament_staff SET status = 'REVOKED' 
        WHERE tournament_id = p_tournament_id AND user_id = v_user_id AND role = 'PLAYER_REFEREE';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### generate_referee_suggestions

```sql
CREATE OR REPLACE FUNCTION generate_referee_suggestions(p_category_id UUID)
RETURNS TABLE(match_id UUID, user_id UUID) AS $$
DECLARE
    v_match RECORD;
    v_referees UUID[];
    v_referee_idx INTEGER := 0;
    v_referee_counts UUID[] := ARRAY[]::UUID[];
BEGIN
    -- Obtener matches sin referee confirmado
    FOR v_match IN 
        SELECT m.id, m.round_name
        FROM matches m
        WHERE m.category_id = p_category_id
          AND m.referee_id IS NULL
        ORDER BY m.round_name
    LOOP
        -- Obtener referees disponibles para este match (round-robin)
        SELECT ARRAY(
            SELECT ar.user_id
            FROM available_referees(ar.match_id) ar
            CROSS JOIN LATERAL (SELECT ar.user_id) ar2
            WHERE ar.match_id = v_match.id
            ORDER BY COALESCE(
                (SELECT COUNT(*) FROM referee_assignments ra WHERE ra.user_id = ar.user_id AND ra.is_confirmed = TRUE),
                0
            ) ASC
            LIMIT 10
        ) INTO v_referees;
        
        -- Seleccionar siguiente referee en round-robin
        IF array_length(v_referees, 1) > 0 THEN
            v_referee_idx := (v_referee_idx % array_length(v_referees, 1)) + 1;
            
            -- Insertar sugerencia
            INSERT INTO referee_assignments (match_id, user_id, assigned_by, is_suggested)
            VALUES (v_match.id, v_referees[v_referee_idx], auth.uid(), TRUE)
            ON CONFLICT (match_id) DO UPDATE SET user_id = v_referees[v_referee_idx], is_suggested = TRUE;
            
            match_id := v_match.id;
            user_id := v_referees[v_referee_idx];
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## RLS Policies Actualizadas

```sql
-- tournament_staff: Organizer ve todo, usuarios ven su propio registro
CREATE POLICY "Staff can view own record" ON tournament_staff
FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Organizers can view all staff" ON tournament_staff
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts2
        WHERE ts2.tournament_id = tournament_staff.tournament_id
          AND ts2.user_id = auth.uid()
          AND ts2.role = 'ORGANIZER'
          AND ts2.status = 'ACTIVE'
    )
);

-- matches: Players pueden ver, solo refs asignados pueden escribir
CREATE POLICY "Anyone authenticated can view matches" ON matches
FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Referee or Organizer can update match" ON matches
FOR UPDATE USING (
    referee_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM tournament_staff ts
        JOIN categories c ON c.tournament_id = ts.tournament_id
        WHERE c.id = matches.category_id
          AND ts.user_id = auth.uid()
          AND ts.role = 'ORGANIZER'
          AND ts.status = 'ACTIVE'
    )
);
```

## Open Questions

- [ ] ¿El sistema debe manejar invitaciones por email? (Excluido por ahora)
- [ ] ¿Los shadow profiles deberían poder ser referess con PIN? (Futuro)
- [ ] ¿Hay límite de matches que un voluntario puede arbitrar por día?

## Next Step

Ready for tasks (sdd-tasks): Implementar las 4 migraciones y seed.
