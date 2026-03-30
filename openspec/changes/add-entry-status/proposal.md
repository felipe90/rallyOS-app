# Proposal: Add `status` Field to `tournament_entries`

## Intent

The payment flow requires tournament entries to have a state machine that transitions from `PENDING_PAYMENT` to `CONFIRMED`. Currently, `tournament_entries` has no status column, breaking the payment confirmation workflow documented in `PAYMENTS_BUSINESS_LOGIC.md`. The automatic bracket generation must only pair entries in `CONFIRMED` state.

## Scope

### In Scope
- Create `entry_status` enum type with values: `PENDING_PAYMENT`, `CONFIRMED`, `CANCELLED`
- Add `status` column to `tournament_entries` table with default `PENDING_PAYMENT`
- Add `fee_amount_snap` column (integer, cents) to capture price at registration time
- Create migration file in `supabase/migrations/`
- Update `supabase/seed.sql` to set existing entries to `CONFIRMED` (payments already SUCCEEDED)
- Add RLS policies to protect status transitions (only system/webhook can confirm)

### Out of Scope
- Backend webhook implementation (future change)
- Frontend UI for entry registration flow (future change)
- Adding `DRAFT` state (deferred for future registration flow enhancement)

## Approach

1. **Create enum**: Add `entry_status` enum type in new migration
2. **Add columns**: Add `status` (default `PENDING_PAYMENT`) and `fee_amount_snap` to `tournament_entries`
3. **Migrate existing seed data**: Update seed.sql to set `status = 'CONFIRMED'` for entries with existing SUCCEEDED payments
4. **RLS hardening**: Ensure only service role can update status (prevent client-side manipulation)

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/` | New | Migration file for enum + columns |
| `supabase/seed.sql` | Modified | Set existing entries to CONFIRMED |
| `supabase/migrations/00000000000001_security_policies.sql` | Modified | RLS for status transitions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Existing entries without payment record | Low | All seed entries have SUCCEEDED payments; add CHECK constraint if needed |
| Client bypass of status check | Low | RLS enforces status transitions server-side only |

## Rollback Plan

```sql
-- Quick rollback: drop columns and type
ALTER TABLE tournament_entries DROP COLUMN IF EXISTS status;
ALTER TABLE tournament_entries DROP COLUMN IF EXISTS fee_amount_snap;
DROP TYPE IF EXISTS entry_status;
```

## Dependencies

- Supabase CLI for running migrations
- No external dependencies

## Success Criteria

- [ ] Migration adds `entry_status` enum with 3 values
- [ ] `tournament_entries` has `status` column with `PENDING_PAYMENT` default
- [ ] `tournament_entries` has `fee_amount_snap` column
- [ ] Seed data entries are `CONFIRMED` (matching existing SUCCEEDED payments)
- [ ] `supabase db reset` completes without errors
- [ ] Security tests pass
