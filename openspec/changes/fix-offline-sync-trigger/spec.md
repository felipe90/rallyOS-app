# Spec: Offline Sync Conflict Resolution Triggers

## Requirements

### R1: Time-Tampering Protection
- **R1.1**: Triggers MUST block updates where `local_updated_at` is more than 5 minutes in the future
- **R1.2**: Error message MUST indicate "Time-Tampering protection"

### R2: Last-Write-Wins Conflict Resolution
- **R2.1**: Updates with older `local_updated_at` MUST be silently rejected (return OLD)
- **R2.2**: Updates with newer or equal `local_updated_at` MUST be allowed

### R3: Trigger Attachment
- **R3.1**: `trg_matches_conflict_resolution` MUST fire BEFORE UPDATE on matches table
- **R3.2**: `trg_scores_conflict_resolution` MUST fire BEFORE UPDATE on scores table
- **R3.3**: Both triggers MUST execute function `check_offline_sync_conflict()`

## Test Scenarios

### Scenario 1: Future Timestamp Blocked (matches)
**Given** a match record exists with `local_updated_at = NOW() - interval '1 hour'`
**When** I UPDATE the match with `local_updated_at = NOW() + interval '10 minutes'`
**Then** the update MUST be rejected with exception "Time-Tampering protection"

### Scenario 2: Future Timestamp Blocked (scores)
**Given** a score record exists with `local_updated_at = NOW() - interval '1 hour'`
**When** I UPDATE the score with `local_updated_at = NOW() + interval '10 minutes'`
**Then** the update MUST be rejected with exception "Time-Tampering protection"

### Scenario 3: Older Timestamp Rejected (matches)
**Given** a match exists with `local_updated_at = '2024-01-01 12:00:00+00'`
**When** I UPDATE with `local_updated_at = '2024-01-01 11:00:00+00'`
**Then** the row MUST remain unchanged (OLD returned)

### Scenario 4: Older Timestamp Rejected (scores)
**Given** a score exists with `local_updated_at = '2024-01-01 12:00:00+00'`
**When** I UPDATE with `local_updated_at = '2024-01-01 11:00:00+00'`
**Then** the row MUST remain unchanged (OLD returned)

### Scenario 5: Newer Timestamp Accepted (matches)
**Given** a match exists with `local_updated_at = '2024-01-01 12:00:00+00'`
**When** I UPDATE with `local_updated_at = '2024-01-01 13:00:00+00'`
**Then** the update MUST succeed

### Scenario 6: Newer Timestamp Accepted (scores)
**Given** a score exists with `local_updated_at = '2024-01-01 12:00:00+00'`
**When** I UPDATE with `local_updated_at = '2024-01-01 13:00:00+00'`
**Then** the update MUST succeed

### Scenario 7: Null local_updated_at Bypasses Check
**Given** a match exists with `local_updated_at = NULL`
**When** I UPDATE the match (any value)
**Then** the update MUST succeed (NULL < anything = false)
