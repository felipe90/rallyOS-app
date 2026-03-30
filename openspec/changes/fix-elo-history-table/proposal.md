# Proposal: Fix Missing `elo_history` Table

## Intent

The `elo_history` table is **referenced but not created** in the schema. Security policies and database functions reference this table (RLS, match completion trigger, rollback), but the table doesn't exist—causing migration failures and runtime errors.

## Scope

### In Scope
- Create `elo_history` table in schema (migration)
- Add RLS policy for SELECT-only access (authenticated users)
- Document the table in domain model alignment

### Out of Scope
- Implementing full ELO calculation logic (already stubbed in `process_match_completion`)
- Retroactive backfill of historical ELO changes

## Approach

1. **Create table** in `00000000000000_init_schema.sql`:
   ```sql
   CREATE TABLE elo_history (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
       sport_id UUID REFERENCES sports(id) ON DELETE CASCADE,
       match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
       previous_elo INTEGER NOT NULL,
       new_elo INTEGER NOT NULL,
       elo_change INTEGER NOT NULL,
       match_timestamp TIMESTAMPTZ DEFAULT NOW()
   );
   ```

2. **Add index** on `(person_id, sport_id)` for efficient history queries.

3. **Verify RLS policy** (already exists in `00000000000001_security_policies.sql` line 57-63) allows SELECT for authenticated users—inserts bypass RLS via SECURITY DEFINER triggers.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000000_init_schema.sql` | Modified | Add `elo_history` table definition |
| `supabase/migrations/00000000000001_security_policies.sql` | Verified | RLS already configured (no changes needed) |
| `docs/DOMAIN_MODEL_V2.md` | Documentation | Align EloLedger entity with actual schema |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Migration order dependency | Low | Table created in init migration, RLS in next |
| Existing code assumes table exists | Medium | Verify `supabase db reset` succeeds after fix |

## Rollback Plan

Revert `00000000000000_init_schema.sql` to remove `elo_history` table. RLS policy will fail gracefully (no table = no policy error at runtime, but functions referencing table will error—acceptable trade-off).

## Success Criteria

- [ ] `supabase db reset` completes without errors
- [ ] `elo_history` table exists and is queryable
- [ ] RLS allows SELECT for authenticated users
- [ ] Match completion trigger executes without errors
