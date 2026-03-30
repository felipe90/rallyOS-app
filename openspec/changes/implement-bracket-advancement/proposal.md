# Proposal: Bracket Advancement Logic

## Intent

Automatically advance tournament bracket winners to the next match when a match finishes. This eliminates manual bracket management and ensures the tournament progresses correctly through semifinals, finals, etc.

## Scope

### In Scope
- Create `advance_bracket_winner()` trigger function in PostgreSQL
- Attach trigger to `matches` table for `AFTER UPDATE` events
- Implement winner determination via sets won in `sets_json`
- Implement automatic placement in next match's `entry_a_id` or `entry_b_id`
- Implement automatic status transition to `SCHEDULED` when next match is ready

### Out of Scope
- Frontend bracket visualization (future change)
- Manual bracket override by organizers (future change)
- Double elimination bracket support (future change)

## Approach

1. **Create trigger function**: `advance_bracket_winner()` that:
   - Fires on `AFTER UPDATE` when `status` changes to `FINISHED`
   - Determines winner by counting sets won in `sets_json`
   - Gets next match via `next_match_id`
   - Places winner in first available slot (`entry_a_id` then `entry_b_id`)
   - Updates next match status to `SCHEDULED` when both entries present

2. **Attach trigger**: Create `trg_advance_bracket` trigger on `matches` table

3. **Test with bracket scenario**: Create semi-finals → final bracket structure

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/` | New | Migration with trigger function |
| N/A | N/A | No application code changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Winner incorrectly determined | Low | Validate sets_json structure in trigger |
| Race condition on simultaneous updates | Low | Trigger runs atomically in transaction |
| NULL next_match_id (final match) | Low | Check for NULL before advancing |

## Rollback Plan

```sql
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;
DROP FUNCTION IF EXISTS advance_bracket_winner();
```

## Dependencies

- Supabase CLI for running migrations
- Existing `matches` table with `entry_a_id`, `entry_b_id`, `next_match_id`, `status`
- Existing `scores` table with `sets_json` containing `a` and `b` set scores

## Success Criteria

- [ ] Migration creates trigger function without errors
- [ ] `supabase db reset` completes without errors
- [ ] Winner of semifinal advances to final when match marked FINISHED
- [ ] Final match status changes to SCHEDULED when both entries present
- [ ] Security tests pass
