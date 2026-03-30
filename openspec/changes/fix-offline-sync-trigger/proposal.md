# Proposal: Fix Offline Sync Trigger Attachment

## Intent

Ensure the `check_offline_sync_conflict()` function has its triggers properly attached to the `matches` and `scores` tables. This provides:
- Time-tampering protection (blocks future timestamps)
- Last-write-wins conflict resolution for offline sync

## Scope

### In Scope
- Verify/attach `trg_matches_conflict_resolution` trigger on matches table
- Verify/attach `trg_scores_conflict_resolution` trigger on scores table
- Create idempotent migration for reproducibility
- Test trigger behavior

### Out of Scope
- Modifying the conflict resolution logic
- Adding triggers to other tables
- Performance optimization of sync logic

## Approach

Create migration `00000000000004_fix_offline_sync_trigger.sql` that:
1. Uses `CREATE TRIGGER IF NOT EXISTS` (or drops and recreates) to ensure triggers are attached
2. Is idempotent - safe to run multiple times

**Note**: Migration 00000000000001 already defines these triggers (lines 87-93), but we create a dedicated fix migration for clarity and as a safeguard.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000004_fix_offline_sync_trigger.sql` | New | Creates/recreates triggers |
| `matches` table | Modified | Gets conflict resolution trigger |
| `scores` table | Modified | Gets conflict resolution trigger |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Trigger already exists causes error | Low | Use OR REPLACE or IF NOT EXISTS |
| Blocking legitimate updates | Low | Only blocks future timestamps + older local_updated_at |

## Rollback Plan

- Drop triggers: `DROP TRIGGER IF EXISTS trg_matches_conflict_resolution ON matches;`
- Drop triggers: `DROP TRIGGER IF EXISTS trg_scores_conflict_resolution ON scores;`
- Re-run previous migration to restore

## Dependencies

- Migration 00000000000001 (creates the function)
- Function `check_offline_sync_conflict()` must exist

## Success Criteria

- [ ] Migration applies without errors
- [ ] Triggers exist in pg_trigger
- [ ] Test: UPDATE with future timestamp is rejected
- [ ] Test: UPDATE with older local_updated_at is rejected (silent)
- [ ] Test: UPDATE with newer local_updated_at succeeds
