# Delta for `elo_history` Table

## ADDED Requirements

### Requirement: ELO History Table Schema

The system MUST define the `elo_history` table with columns for tracking ELO changes across matches and manual adjustments.

```sql
CREATE TABLE elo_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE NOT NULL,
    sport_id UUID REFERENCES sports(id) ON DELETE CASCADE NOT NULL,
    match_id UUID REFERENCES matches(id) ON DELETE SET NULL, -- NULL for manual adjustments
    previous_elo INTEGER NOT NULL,
    new_elo INTEGER NOT NULL,
    elo_change INTEGER NOT NULL, -- positive = gain, negative = loss
    change_type TEXT NOT NULL, -- 'MATCH_WIN', 'MATCH_LOSS', 'ADJUSTMENT'
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Requirement: ELO History Indexes

The system MUST create indexes on `elo_history` to ensure efficient queries.

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_elo_history_person_sport` | `(person_id, sport_id)` | ELO history queries by player and sport |
| `idx_elo_history_match_id` | `match_id` | Match lookup via ELO history |

### Requirement: ELO History RLS Policy

The system MUST enforce row-level security on `elo_history`:

| Operation | Policy | Condition |
|-----------|--------|-----------|
| SELECT | Allow | All authenticated users |
| INSERT | Block direct | Only via SECURITY DEFINER triggers |
| UPDATE | Block | No client updates allowed |
| DELETE | Block | No client deletes allowed |

#### Scenario: Authenticated user reads ELO history

- GIVEN a user is authenticated
- WHEN the user queries `elo_history` for any person/sport
- THEN all matching ELO change records are returned

#### Scenario: Trigger creates ELO entry on match completion

- GIVEN a match exists with `entry_a_id` and `entry_b_id` participants
- WHEN the match status changes to 'FINISHED'
- THEN ELO history entries are created for both players with correct `elo_change` values
- AND `change_type` is set to 'MATCH_WIN' for the winner and 'MATCH_LOSS' for the loser

#### Scenario: Manual ELO adjustment creates history entry

- GIVEN an admin initiates a manual ELO correction
- WHEN the adjustment is applied to a player's ELO
- THEN an `elo_history` entry is created with `match_id = NULL`
- AND `change_type` is set to 'ADJUSTMENT'

### Requirement: ELO History Immutability

The system SHALL NOT allow UPDATE or DELETE operations on `elo_history` entries by any client.

#### Scenario: Client update blocked by RLS

- GIVEN an `elo_history` entry exists
- WHEN a client attempts to UPDATE the record
- THEN the operation is denied with a permission error

#### Scenario: Client delete blocked by RLS

- GIVEN an `elo_history` entry exists
- WHEN a client attempts to DELETE the record
- THEN the operation is denied with a permission error

## Migration Notes

| File | Change |
|------|--------|
| `supabase/migrations/00000000000000_init_schema.sql` | Add `elo_history` table definition and indexes |
| `supabase/migrations/00000000000001_security_policies.sql` | Verify RLS policy exists (already configured) |
| `docs/DOMAIN_MODEL_V2.md` | Align EloLedger entity with actual schema |

## Success Criteria

- [ ] `supabase db reset` completes without errors
- [ ] `elo_history` table exists and is queryable
- [ ] Indexes are created on `person_id, sport_id` and `match_id`
- [ ] RLS allows SELECT for authenticated users
- [ ] RLS blocks UPDATE/DELETE for all clients
- [ ] Match completion trigger executes without errors
