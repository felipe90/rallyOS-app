# Tasks: Fix Offline Sync Trigger Attachment

## Implementation

- [x] **T1**: Create migration `supabase/migrations/00000000000004_fix_offline_sync_trigger.sql`
  - Create trigger for matches table
  - Create trigger for scores table
  - Use idempotent approach (CREATE OR REPLACE)

## Verification

- [x] **T2**: Apply migration
  - Run `supabase db reset` or apply migration directly
  
- [x] **T3**: Verify triggers exist
  - Query `pg_trigger` for both triggers
  
- [x] **T4**: Test R1 (future timestamp blocked)
  - Attempt update with future timestamp
  - Verify exception raised
  - Result: ✅ "Timestamp in the future is not allowed (Time-Tampering protection)"
  
- [x] **T5**: Test R2 (older timestamp rejected)
  - Attempt update with older timestamp
  - Verify OLD is returned (no change)
  - Result: ✅ Update silently rejected, data unchanged
  
- [x] **T6**: Test R2 (newer timestamp allowed)
  - Attempt update with newer timestamp
  - Verify update succeeds
  - Result: ✅ Update succeeded
