# Proposal: Fix public_tournament_snapshot View Column Mismatch

## Intent

Fix broken `public_tournament_snapshot` view that references non-existent `last_known_elo` column. The view must use the correct `current_elo` column from `athlete_stats` table to enable privacy-safe snapshot queries for clients.

## Scope

### In Scope
- Verify `public_tournament_snapshot` view uses correct column references
- Ensure view columns match actual `athlete_stats` schema
- Document required columns: `person_id`, `first_name`, `display_name`, `current_elo`, `sport_id`

### Out of Scope
- Schema migrations beyond the view fix
- RLS policy changes
- ELO calculation logic

## Approach

**Verification and documentation only** — the view fix has already been applied.

The current view definition (lines 14-22 of `00000000000001_security_policies.sql`):
```sql
CREATE OR REPLACE VIEW public_tournament_snapshot AS
SELECT 
    p.id AS person_id,
    p.first_name,
    COALESCE(p.nickname, p.last_name) AS display_name,
    ast.current_elo AS current_elo,  -- ✓ Correct
    ast.sport_id
FROM persons p
JOIN athlete_stats ast ON p.id = ast.person_id;
```

This matches the `athlete_stats` schema which has `current_elo INTEGER DEFAULT 1000`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000001_security_policies.sql` | Verified | View uses `ast.current_elo` — ✓ Correct |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Query failures on client | None | View fixed; columns match schema |
| Data inconsistency | Low | View is a simple SELECT; no transforms |

## Rollback Plan

No rollback needed — this was a column name correction. If issues arise, restore by changing `ast.current_elo` to the correct column name in `athlete_stats`.

## Dependencies

- `athlete_stats.current_elo` column exists (verified in `00000000000000_init_schema.sql`)

## Success Criteria

- [ ] View `public_tournament_snapshot` compiles without errors
- [ ] View references `current_elo`, not `last_known_elo`
- [ ] Security tests pass: `psql ... -f supabase/tests/security_tests.sql`
