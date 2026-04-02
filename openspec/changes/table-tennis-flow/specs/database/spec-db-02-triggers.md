# SPEC-DB-02: Database Triggers - Round Robin Logic

## Purpose

Definir los triggers necesarios para mantener la integridad del modelo Round Robin en RallyOS.

---

## Trigger: trg_validate_member_count

**Table**: `round_robin_groups`
**Event**: BEFORE INSERT OR UPDATE ON `group_members`
**Purpose**: Validar que el grupo no exceda 5 miembros.

```sql
CREATE OR REPLACE FUNCTION fn_validate_group_member_count()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    max_members INTEGER := 5;
BEGIN
    -- Get current member count (excluding the one being updated)
    SELECT COUNT(*) INTO current_count
    FROM group_members
    WHERE group_id = NEW.group_id
    AND id != NEW.id;
    
    IF current_count >= max_members THEN
        RAISE EXCEPTION 'Group cannot have more than % members', max_members;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_group_member_count
BEFORE INSERT OR UPDATE ON group_members
FOR EACH ROW EXECUTE FUNCTION fn_validate_group_member_count();
```

**Behavior:**
- INSERT: Rechaza si el grupo ya tiene 5 miembros
- UPDATE: No aplica (cambiar de grupo es un caso especial manejado por RPC)

---

## Trigger: trg_unique_person_per_tournament

**Table**: `group_members`
**Event**: BEFORE INSERT ON `group_members`
**Purpose**: Un persona no puede estar en dos grupos del mismo torneo.

```sql
CREATE OR REPLACE FUNCTION fn_unique_person_per_tournament()
RETURNS TRIGGER AS $$
DECLARE
    existing_group_id UUID;
BEGIN
    -- Find if person is already in another group of same tournament
    SELECT gm.group_id INTO existing_group_id
    FROM group_members gm
    JOIN round_robin_groups rrg ON gm.group_id = rrg.id
    WHERE gm.person_id = NEW.person_id
    AND rrg.tournament_id = (
        SELECT tournament_id FROM round_robin_groups WHERE id = NEW.group_id
    )
    AND gm.id != NEW.id;  -- Exclude self for updates
    
    IF existing_group_id IS NOT NULL THEN
        RAISE EXCEPTION 'Person % is already in a group for this tournament', NEW.person_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_unique_person_per_tournament
BEFORE INSERT ON group_members
FOR EACH ROW EXECUTE FUNCTION fn_unique_person_per_tournament();
```

---

## Trigger: trg_unique_seed_per_group

**Table**: `group_members`
**Event**: BEFORE INSERT OR UPDATE ON `group_members`
**Purpose**: Solo un miembro puede tener cada valor de seed.

```sql
CREATE OR REPLACE FUNCTION fn_unique_seed_per_group()
RETURNS TRIGGER AS $$
DECLARE
    existing_seed INTEGER;
BEGIN
    SELECT seed INTO existing_seed
    FROM group_members
    WHERE group_id = NEW.group_id
    AND seed = NEW.seed
    AND id != NEW.id;
    
    IF existing_seed IS NOT NULL THEN
        RAISE EXCEPTION 'Seed % already exists in group %', NEW.seed, NEW.group_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_unique_seed_per_group
BEFORE INSERT OR UPDATE ON group_members
FOR EACH ROW EXECUTE FUNCTION fn_unique_seed_per_group();
```

---

## Trigger: trg_update_group_status

**Table**: `matches`
**Event**: AFTER UPDATE ON `matches`
**Purpose**: Actualizar estado del grupo cuando todos los matches terminan.

```sql
CREATE OR REPLACE FUNCTION fn_update_group_status_on_match_complete()
RETURNS TRIGGER AS $$
DECLARE
    v_group_id UUID;
    v_pending_matches INTEGER;
    v_group_status group_status;
BEGIN
    -- Only trigger on status change to FINISHED or WALKED_OVER
    IF OLD.status IN ('FINISHED', 'WALKED_OVER') THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status NOT IN ('FINISHED', 'WALKED_OVER') THEN
        RETURN NEW;
    END IF;
    
    -- Get group_id from match
    SELECT group_id INTO v_group_id FROM matches WHERE id = NEW.id;
    
    IF v_group_id IS NULL THEN
        RETURN NEW;  -- Not a group match, skip
    END IF;
    
    -- Count pending matches in group
    SELECT COUNT(*) INTO v_pending_matches
    FROM matches
    WHERE group_id = v_group_id
    AND status NOT IN ('FINISHED', 'WALKED_OVER', 'CANCELLED');
    
    -- Update group status
    IF v_pending_matches = 0 THEN
        UPDATE round_robin_groups
        SET status = 'COMPLETED', updated_at = NOW()
        WHERE id = v_group_id;
    ELSE
        -- Check if group is IN_PROGRESS
        SELECT status INTO v_group_status FROM round_robin_groups WHERE id = v_group_id;
        IF v_group_status = 'PENDING' THEN
            UPDATE round_robin_groups
            SET status = 'IN_PROGRESS', updated_at = NOW()
            WHERE id = v_group_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_group_status
AFTER UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION fn_update_group_status_on_match_complete();
```

---

## Trigger: trg_validate_intra_group_referee

**Table**: `referee_assignments`
**Event**: BEFORE INSERT OR UPDATE ON `referee_assignments`
**Purpose**: Para matches de Round Robin, el referee DEBE ser del mismo grupo.

```sql
CREATE OR REPLACE FUNCTION fn_validate_intra_group_referee()
RETURNS TRIGGER AS $$
DECLARE
    v_match_group_id UUID;
    v_match_entry_a UUID;
    v_match_entry_b UUID;
    v_referee_group_id UUID;
    v_match_phase match_phase;
BEGIN
    -- Get match info
    SELECT 
        m.group_id,
        m.entry_a_id,
        m.entry_b_id,
        m.phase
    INTO v_match_group_id, v_match_entry_a, v_match_entry_b, v_match_phase
    FROM matches m
    WHERE m.id = NEW.match_id;
    
    -- If no group (bracket match), skip validation
    IF v_match_group_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- If not ROUND_ROBIN phase, skip (KO allows any referee)
    IF v_match_phase != 'ROUND_ROBIN' THEN
        RETURN NEW;
    END IF;
    
    -- Get referee's group_id
    SELECT gm.group_id INTO v_referee_group_id
    FROM group_members gm
    JOIN tournament_entries te ON gm.entry_id = te.id
    JOIN persons p ON te.person_id = p.id
    JOIN auth.users au ON p.user_id = au.id
    WHERE au.id = NEW.user_id;
    
    -- Validate referee is in same group
    IF v_referee_group_id != v_match_group_id THEN
        RAISE EXCEPTION 'Referee must be from the same Round Robin group';
    END IF;
    
    -- Validate referee is not playing
    IF v_referee_group_id IS NOT NULL THEN
        -- Get entry_id of referee
        -- This check is done by ensuring referee person is not in entry_a or entry_b
        -- via the application layer, but we can do a basic check here
        IF EXISTS (
            SELECT 1 FROM group_members gm
            JOIN tournament_entries te ON gm.entry_id = te.id
            JOIN persons p ON te.person_id = p.id
            JOIN auth.users au ON p.user_id = au.id
            WHERE au.id = NEW.user_id
            AND gm.entry_id IN (v_match_entry_a, v_match_entry_b)
        ) THEN
            RAISE EXCEPTION 'Referee cannot be one of the players';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_intra_group_referee
BEFORE INSERT OR UPDATE ON referee_assignments
FOR EACH ROW EXECUTE FUNCTION fn_validate_intra_group_referee();
```

---

## Trigger: trg_track_loser_for_referee

**Table**: `matches`
**Event**: AFTER UPDATE ON `matches` (status → FINISHED)
**Purpose**: Cuando un match termina, guardar el perdedor para posible asignación como referee.

```sql
CREATE OR REPLACE FUNCTION fn_track_loser_for_referee()
RETURNS TRIGGER AS $$
DECLARE
    v_winner_entry_id UUID;
    v_loser_entry_id UUID;
    v_loser_user_id UUID;
    v_next_match_id UUID;
BEGIN
    -- Only trigger when status changes to FINISHED
    IF OLD.status = 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status != 'FINISHED' THEN
        RETURN NEW;
    END IF;
    
    -- Determine winner and loser from score
    -- (Assuming score is already updated)
    SELECT 
        CASE 
            WHEN s.points_a > s.points_b THEN m.entry_a_id
            ELSE m.entry_b_id
        END INTO v_winner_entry_id,
        CASE 
            WHEN s.points_a > s.points_b THEN m.entry_b_id
            ELSE m.entry_a_id
        END INTO v_loser_entry_id
    FROM matches m
    JOIN scores s ON m.id = s.match_id
    WHERE m.id = NEW.id;
    
    -- Get loser user_id
    SELECT te.person_id INTO v_loser_entry_id
    FROM tournament_entries te
    WHERE te.id = v_loser_entry_id;
    
    -- Get actual user_id from person
    SELECT p.user_id INTO v_loser_user_id
    FROM persons p
    WHERE p.id = v_loser_entry_id;
    
    -- Get next match of winner
    SELECT next_match_id INTO v_next_match_id
    FROM matches
    WHERE id = NEW.id;
    
    -- Store loser user_id for potential referee assignment
    IF v_loser_user_id IS NOT NULL AND v_next_match_id IS NOT NULL THEN
        UPDATE matches
        SET loser_assigned_referee = v_loser_user_id
        WHERE id = v_next_match_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_track_loser_for_referee
AFTER UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION fn_track_loser_for_referee();
```

**Note**: This is a simplified version. The actual implementation needs to handle:
1. Getting the loser from the score (requires score to be committed first)
2. Handling the case where loser is a shadow profile (no user_id)
3. Cross-group validation before assignment

---

## Trigger: trg_update_referee_stats_on_assignment

**Table**: `referee_assignments`
**Event**: AFTER INSERT ON `referee_assignments`
**Purpose**: Incrementar matches_refereed en athlete_stats.

```sql
CREATE OR REPLACE FUNCTION fn_update_referee_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_person_id UUID;
    v_sport_id UUID;
BEGIN
    -- Get person_id from user
    SELECT p.id, te.sport_id INTO v_person_id, v_sport_id
    FROM auth.users au
    JOIN persons p ON au.id = p.user_id
    JOIN tournament_entries te ON te.person_id = p.id
    JOIN matches m ON m.entry_a_id = te.id OR m.entry_b_id = te.id
    WHERE m.id = NEW.match_id
    LIMIT 1;
    
    IF v_person_id IS NOT NULL AND v_sport_id IS NOT NULL THEN
        UPDATE athlete_stats
        SET matches_refereed = matches_refereed + 1
        WHERE person_id = v_person_id AND sport_id = v_sport_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_referee_stats_on_assignment
AFTER INSERT ON referee_assignments
FOR EACH ROW EXECUTE FUNCTION fn_update_referee_stats();
```

---

## Trigger: trg_validate_score_tt_rules

**Table**: `scores`
**Event**: BEFORE INSERT OR UPDATE ON `scores`
**Purpose**: Validar que el score cumpla reglas de Table Tennis.

```sql
CREATE OR REPLACE FUNCTION fn_validate_score_tt_rules()
RETURNS TRIGGER AS $$
DECLARE
    v_sport_id UUID;
    v_scoring_config JSONB;
    v_points_to_win INTEGER;
    v_win_by_2 BOOLEAN;
    v_deuce_at INTEGER;
    v_current_set INTEGER;
    v_sets_played INTEGER;
BEGIN
    -- Get sport scoring config from match
    SELECT 
        t.sport_id,
        s.scoring_config
    INTO v_sport_id, v_scoring_config
    FROM matches m
    JOIN categories c ON m.category_id = c.id
    JOIN tournaments t ON c.tournament_id = t.id
    JOIN sports s ON t.sport_id = s.id
    WHERE m.id = NEW.match_id;
    
    -- Extract TT-specific values
    v_points_to_win := COALESCE(
        (v_scoring_config->>'points_per_set')::INTEGER,
        11
    );
    v_win_by_2 := COALESCE(
        (v_scoring_config->>'win_by_2')::BOOLEAN,
        TRUE
    );
    v_deuce_at := COALESCE(
        (v_scoring_config->>'deuce_at')::INTEGER,
        10
    );
    
    -- Allow 0-0 as initial state
    IF NEW.points_a = 0 AND NEW.points_b = 0 THEN
        RETURN NEW;
    END IF;
    
    -- Get current set number
    SELECT COALESCE(MAX(set_number), 0) INTO v_sets_played
    FROM match_sets
    WHERE match_id = NEW.match_id;
    
    -- TT Validation Rules:
    -- 1. Points must be non-negative
    IF NEW.points_a < 0 OR NEW.points_b < 0 THEN
        RAISE EXCEPTION 'Points cannot be negative';
    END IF;
    
    -- 2. If both < deuce_at + 1, one must be ahead by 1
    IF NEW.points_a < v_deuce_at + 1 AND NEW.points_b < v_deuce_at + 1 THEN
        IF ABS(NEW.points_a - NEW.points_b) != 1 THEN
            RAISE EXCEPTION 'Before deuce, difference must be 1 point';
        END IF;
    END IF;
    
    -- 3. If one reaches v_deuce_at + 1 (11), must win by 2
    IF (NEW.points_a >= v_points_to_win OR NEW.points_b >= v_points_to_win) THEN
        IF v_win_by_2 THEN
            IF ABS(NEW.points_a - NEW.points_b) < 2 THEN
                RAISE EXCEPTION 'Must win by 2 points in TT';
            END IF;
        END IF;
    END IF;
    
    -- 4. Extended deuce: if both >= deuce_at, continue until diff = 2
    IF NEW.points_a >= v_deuce_at AND NEW.points_b >= v_deuce_at THEN
        IF ABS(NEW.points_a - NEW.points_b) != 2 THEN
            RAISE EXCEPTION 'In deuce, must win by 2 points';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_score_tt_rules
BEFORE INSERT OR UPDATE ON scores
FOR EACH ROW EXECUTE FUNCTION fn_validate_score_tt_rules();
```

---

## Summary Table

| Trigger | Table | Event | Purpose |
|---------|-------|-------|---------|
| trg_validate_group_member_count | group_members | BEFORE INSERT/UPDATE | Max 5 members |
| trg_unique_person_per_tournament | group_members | BEFORE INSERT | One group per person |
| trg_unique_seed_per_group | group_members | BEFORE INSERT/UPDATE | Unique seeds |
| trg_update_group_status | matches | AFTER UPDATE | Auto-complete group |
| trg_validate_intra_group_referee | referee_assignments | BEFORE INSERT/UPDATE | Same-group only |
| trg_track_loser_for_referee | matches | AFTER UPDATE | Store loser for next match |
| trg_update_referee_stats | referee_assignments | AFTER INSERT | Increment stats |
| trg_validate_score_tt_rules | scores | BEFORE INSERT/UPDATE | TT score validation |
