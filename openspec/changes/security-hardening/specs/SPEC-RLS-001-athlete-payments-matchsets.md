# SPEC-SEC-RLS-001: Row-Level Security on Sensitive Tables

## Purpose

Add RLS policies to 3 critical tables that currently expose sensitive user data:
- `athlete_stats` - ELO ratings and match statistics
- `payments` - Payment records with amounts and provider info
- `match_sets` - Detailed score data per set

## Background

Current state audit revealed these tables have NO RLS policies, allowing any authenticated user to read/modify sensitive data.

## Requirements

### Requirement: athlete_stats RLS

**athletes_stats** table contains:
- `current_elo` - Sensitive competitive rating
- `matches_played`, `matches_won` - Performance metrics
- `rank` - Calculated badge

#### Scenario: Public Profile View
- GIVEN a user views a public profile
- WHEN the profile displays ELO and stats
- THEN the system uses a SERVICE ROLE or SECURITY DEFINER function
- AND users cannot directly query athlete_stats

#### Scenario: Own Stats Update
- GIVEN a player wants to update their profile
- WHEN they request to modify their data
- THEN the system validates ownership via `persons.user_id`
- AND allows UPDATE only for own records
- AND organizers can SELECT all

**Policies Required:**
```sql
-- SELECT: Anyone authenticated can view (for profiles)
CREATE POLICY "Authenticated users can view athlete stats"
ON athlete_stats FOR SELECT TO authenticated
USING (TRUE);

-- UPDATE: Only own record (via persons.user_id link)
CREATE POLICY "Players can update own stats"
ON athlete_stats FOR UPDATE TO authenticated
USING (
    person_id IN (
        SELECT id FROM persons WHERE user_id = auth.uid()
    )
);

-- INSERT/DELETE: Blocked for all (via triggers only)
```

### Requirement: payments RLS

**payments** table contains:
- `amount` - Payment amount
- `provider` - Payment provider (STRIPE, etc)
- `provider_txn_id` - Transaction reference
- `status` - Payment status

#### Scenario: User Views Own Payment
- GIVEN a user views their payment history
- WHEN they query payments
- THEN they see only their own payments
- AND cannot see other users' payment data

#### Scenario: Organizer Views Tournament Payments
- GIVEN a tournament organizer
- WHEN they view payments for their tournament
- THEN they see all payments for entries in their tournaments
- AND can see amounts and status (but NOT provider_txn_id)

**Policies Required:**
```sql
-- SELECT: Own payments OR tournament organizer
CREATE POLICY "Users can view own payments"
ON payments FOR SELECT TO authenticated
USING (
    -- Own payment
    user_id = auth.uid()
    OR
    -- Tournament organizer can see tournament entries' payments
    tournament_entry_id IN (
        SELECT te.id FROM tournament_entries te
        JOIN categories c ON c.id = te.category_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);

-- INSERT: Only via payment processor (blocked for users)
CREATE POLICY "Payments insert blocked for users"
ON payments FOR INSERT TO authenticated WITH CHECK (FALSE);

-- UPDATE: Only status changes by organizer or system
CREATE POLICY "Organizers can update payment status"
ON payments FOR UPDATE TO authenticated
USING (
    tournament_entry_id IN (
        SELECT te.id FROM tournament_entries te
        JOIN categories c ON c.id = te.category_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
        AND ts.status = 'ACTIVE'
    )
);
```

### Requirement: match_sets RLS

**match_sets** table contains:
- `set_number`, `points_a`, `points_b` - Set scores
- `is_tiebreak`, `is_finished` - Set status

#### Scenario: View Match Details
- GIVEN a user views match details
- WHEN they see the set-by-set breakdown
- THEN they can see all completed sets
- AND live sets visible only to participants/organizers

#### Scenario: Score Entry
- GIVEN a referee enters set scores
- WHEN they submit a set score
- THEN it goes through scores table trigger
- AND match_sets should NOT be directly modifiable by users

**Policies Required:**
```sql
-- SELECT: Anyone authenticated
CREATE POLICY "Authenticated users can view match sets"
ON match_sets FOR SELECT TO authenticated
USING (TRUE);

-- INSERT/UPDATE/DELETE: Blocked (via scores table only)
CREATE POLICY "Match sets modified via scores trigger only"
ON match_sets FOR INSERT TO authenticated WITH CHECK (FALSE);

CREATE POLICY "Match sets update blocked"
ON match_sets FOR UPDATE TO authenticated USING (FALSE);

CREATE POLICY "Match sets delete blocked"
ON match_sets FOR DELETE TO authenticated USING (FALSE);
```

## Migration

File: `supabase/migrations/00000000000048_rls_sensitive_tables.sql`

```sql
-- Enable RLS
ALTER TABLE athlete_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_sets ENABLE ROW LEVEL SECURITY;

-- athlete_stats policies
CREATE POLICY "Authenticated users can view athlete stats"
ON athlete_stats FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Players can update own stats"
ON athlete_stats FOR UPDATE TO authenticated
USING (person_id IN (SELECT id FROM persons WHERE user_id = auth.uid()));

-- payments policies
CREATE POLICY "Users can view own payments"
ON payments FOR SELECT TO authenticated
USING (
    user_id = auth.uid()
    OR tournament_entry_id IN (
        SELECT te.id FROM tournament_entries te
        JOIN categories c ON c.id = te.category_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ts.user_id = auth.uid() AND ts.role = 'ORGANIZER' AND ts.status = 'ACTIVE'
    )
);

CREATE POLICY "Payments insert blocked for users"
ON payments FOR INSERT TO authenticated WITH CHECK (FALSE);

CREATE POLICY "Organizers can update payment status"
ON payments FOR UPDATE TO authenticated
USING (
    tournament_entry_id IN (
        SELECT te.id FROM tournament_entries te
        JOIN categories c ON c.id = te.category_id
        JOIN tournament_staff ts ON ts.tournament_id = c.tournament_id
        WHERE ts.user_id = auth.uid() AND ts.role = 'ORGANIZER' AND ts.status = 'ACTIVE'
    )
);

-- match_sets policies
CREATE POLICY "Authenticated users can view match sets"
ON match_sets FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Match sets modified via scores trigger only"
ON match_sets FOR INSERT TO authenticated WITH CHECK (FALSE);

CREATE POLICY "Match sets update blocked"
ON match_sets FOR UPDATE TO authenticated USING (FALSE);

CREATE POLICY "Match sets delete blocked"
ON match_sets FOR DELETE TO authenticated USING (FALSE);
```

## Verification

```sql
-- Verify RLS enabled
SELECT tablename, relrowsecurity FROM pg_class
WHERE relname IN ('athlete_stats', 'payments', 'match_sets');

-- Verify policies count
SELECT tablename, COUNT(*) FROM pg_policies
WHERE tablename IN ('athlete_stats', 'payments', 'match_sets')
GROUP BY tablename;
```

## Expected Outcome

- athlete_stats: 2 policies (SELECT, UPDATE)
- payments: 3 policies (SELECT, INSERT, UPDATE)
- match_sets: 4 policies (SELECT, INSERT, UPDATE, DELETE)
