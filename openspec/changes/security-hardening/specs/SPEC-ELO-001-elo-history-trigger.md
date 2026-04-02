# SPEC-SEC-ELO-001: Auto-populate elo_history Trigger

## Purpose

Create a trigger that automatically populates the `elo_history` table whenever an athlete's ELO rating changes in `athlete_stats`.

## Background

The `elo_history` table exists with proper schema but has 0 records because no trigger was created to populate it.

This table is essential for:
- Audit trail of ELO changes
- Preventing ELO manipulation
- Calculating trends over time
- Debugging ELO calculation issues

## Data Model

### elo_history Table Structure

```sql
CREATE TABLE elo_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES sports(id) ON DELETE CASCADE,
    match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
    previous_elo INTEGER NOT NULL,
    new_elo INTEGER NOT NULL,
    elo_change INTEGER NOT NULL,
    change_type elo_change_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT elo_change_matches_delta CHECK (elo_change = new_elo - previous_elo)
);

-- Indexes
CREATE INDEX idx_elo_history_person_sport ON elo_history(person_id, sport_id);
CREATE INDEX idx_elo_history_match_id ON elo_history(match_id);
```

### elo_change_type Enum

```sql
CREATE TYPE elo_change_type AS ENUM (
    'MATCH_WIN',
    'MATCH_LOSS', 
    'ADJUSTMENT',
    'TOURNAMENT_BONUS'
);
```

## Requirements

### Requirement: Detect ELO Changes

The trigger must detect when `current_elo` changes in `athlete_stats`.

**Scenario: Match Completion**
- GIVEN a match is completed
- WHEN the ELO is calculated and updated in `athlete_stats`
- THEN a record is inserted into `elo_history` with:
  - `previous_elo`: Value before update
  - `new_elo`: Value after update
  - `elo_change`: Calculated difference
  - `change_type`: 'MATCH_WIN' or 'MATCH_LOSS'
  - `match_id`: The match that caused the change

**Scenario: Manual Adjustment**
- GIVEN an organizer adjusts a player's ELO
- WHEN the adjustment is applied
- THEN a record is inserted with:
  - `change_type`: 'ADJUSTMENT'
  - `match_id`: NULL (manual adjustment)

**Scenario: Tournament Bonus**
- GIVEN a player completes a tournament
- WHEN a participation bonus is applied
- THEN a record is inserted with:
  - `change_type`: 'TOURNAMENT_BONUS'
  - `match_id`: NULL

### Requirement: Trigger Implementation

Use a `BEFORE UPDATE` trigger on `athlete_stats` to capture the OLD value before the change:

```sql
CREATE OR REPLACE FUNCTION fn_record_elo_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only record if current_elo changed
    IF OLD.current_elo != NEW.current_elo THEN
        INSERT INTO elo_history (
            person_id,
            sport_id,
            match_id,
            previous_elo,
            new_elo,
            elo_change,
            change_type
        ) VALUES (
            NEW.person_id,
            NEW.sport_id,
            NEW.match_id,  -- Will be NULL for manual adjustments
            OLD.current_elo,
            NEW.current_elo,
            NEW.current_elo - OLD.current_elo,
            CASE 
                WHEN NEW.current_elo > OLD.current_elo THEN 'MATCH_WIN'
                WHEN NEW.current_elo < OLD.current_elo THEN 'MATCH_LOSS'
                ELSE 'ADJUSTMENT'
            END::elo_change_type
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_record_elo_change
BEFORE UPDATE OF current_elo ON athlete_stats
FOR EACH ROW
EXECUTE FUNCTION fn_record_elo_change();
```

### Requirement: Track Match Context

The `athlete_stats` table doesn't have a `match_id` column. We need to add it:

```sql
ALTER TABLE athlete_stats 
ADD COLUMN IF NOT EXISTS last_match_id UUID REFERENCES matches(id) ON DELETE SET NULL;
```

Then update the trigger to use this field:

```sql
CREATE OR REPLACE FUNCTION fn_record_elo_change()
RETURNS TRIGGER AS $$
DECLARE
    v_match_id UUID;
    v_change_type elo_change_type;
BEGIN
    -- Only record if current_elo changed
    IF OLD.current_elo != NEW.current_elo THEN
        -- Get match_id from the column we added
        v_match_id := NEW.last_match_id;
        
        -- Determine change type based on direction
        IF NEW.current_elo > OLD.current_elo THEN
            v_change_type := 'MATCH_WIN';
        ELSIF NEW.current_elo < OLD.current_elo THEN
            v_change_type := 'MATCH_LOSS';
        ELSE
            v_change_type := 'ADJUSTMENT';
        END IF;
        
        INSERT INTO elo_history (
            person_id,
            sport_id,
            match_id,
            previous_elo,
            new_elo,
            elo_change,
            change_type
        ) VALUES (
            NEW.person_id,
            NEW.sport_id,
            v_match_id,
            OLD.current_elo,
            NEW.current_elo,
            NEW.current_elo - OLD.current_elo,
            v_change_type
        );
        
        -- Clear last_match_id after recording
        NEW.last_match_id := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Requirement: RLS for elo_history

The `elo_history` table should be INSERT-only (writes via trigger only):

```sql
ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;

-- Anyone can view their own history
CREATE POLICY "Users can view own ELO history"
ON elo_history FOR SELECT TO authenticated
USING (person_id IN (SELECT id FROM persons WHERE user_id = auth.uid()));

-- Organizers can view all
CREATE POLICY "Organizers can view tournament ELO history"
ON elo_history FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM athlete_stats ast
        JOIN categories c ON c.sport_id = ast.sport_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ast.person_id = elo_history.person_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);

-- No INSERT policy (writes via trigger only)
-- No UPDATE/DELETE policies
```

## Migration

File: `supabase/migrations/00000000000050_elo_history_trigger.sql`

```sql
-- 1. Add last_match_id column to athlete_stats
ALTER TABLE athlete_stats 
ADD COLUMN IF NOT EXISTS last_match_id UUID REFERENCES matches(id) ON DELETE SET NULL;

-- 2. Create trigger function
CREATE OR REPLACE FUNCTION fn_record_elo_change()
RETURNS TRIGGER AS $$
DECLARE
    v_match_id UUID;
    v_change_type elo_change_type;
BEGIN
    -- Only record if current_elo changed
    IF OLD.current_elo != NEW.current_elo THEN
        v_match_id := NEW.last_match_id;
        
        IF NEW.current_elo > OLD.current_elo THEN
            v_change_type := 'MATCH_WIN';
        ELSIF NEW.current_elo < OLD.current_elo THEN
            v_change_type := 'MATCH_LOSS';
        ELSE
            v_change_type := 'ADJUSTMENT';
        END IF;
        
        INSERT INTO elo_history (
            person_id,
            sport_id,
            match_id,
            previous_elo,
            new_elo,
            elo_change,
            change_type
        ) VALUES (
            NEW.person_id,
            NEW.sport_id,
            v_match_id,
            OLD.current_elo,
            NEW.current_elo,
            NEW.current_elo - OLD.current_elo,
            v_change_type
        );
        
        -- Clear last_match_id after recording
        NEW.last_match_id := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger
DROP TRIGGER IF EXISTS trg_record_elo_change ON athlete_stats;
CREATE TRIGGER trg_record_elo_change
BEFORE UPDATE OF current_elo ON athlete_stats
FOR EACH ROW
EXECUTE FUNCTION fn_record_elo_change();

-- 4. Enable RLS on elo_history
ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies
CREATE POLICY "Users can view own ELO history"
ON elo_history FOR SELECT TO authenticated
USING (person_id IN (SELECT id FROM persons WHERE user_id = auth.uid()));

CREATE POLICY "Organizers can view tournament ELO history"
ON elo_history FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM athlete_stats ast
        JOIN categories c ON c.sport_id = ast.sport_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ast.person_id = elo_history.person_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);
```

## Verification

```sql
-- 1. Verify column exists
SELECT column_name FROM information_schema.columns
WHERE table_name = 'athlete_stats' AND column_name = 'last_match_id';

-- 2. Verify trigger exists
SELECT tgname, tgtype, proname
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE tgname = 'trg_record_elo_change';

-- 3. Verify RLS on elo_history
SELECT relrowsecurity FROM pg_class WHERE relname = 'elo_history';

-- 4. Test: Update an athlete's ELO and check history
-- (requires match completion flow)
```

## Expected Outcome

- `athlete_stats.last_match_id` column exists
- `trg_record_elo_change` trigger active on `athlete_stats`
- `elo_history` has RLS policies for SELECT
- ELO changes automatically recorded with correct `change_type`
- `previous_elo`, `new_elo`, `elo_change` all correct
