# Proposal: Security Hardening - RallyOS

## Summary

Implement critical security fixes to make RallyOS production-ready by addressing 3 major gaps identified in the system evaluation.

## Problem Statement

The evaluation revealed 3 critical security vulnerabilities:

1. **Tables Without RLS**: `athlete_stats`, `payments`, `match_sets` expose sensitive user data
2. **RPCs Without SECURITY DEFINER**: All critical RPCs lack proper security context handling
3. **elo_history Not Populated**: Audit trail table exists but has no trigger to populate it

## Impact

| Vulnerability | Risk | Impact |
|--------------|------|--------|
| athlete_stats no RLS | HIGH | Anyone can read/modify ELO ratings |
| payments no RLS | CRITICAL | Payment data exposed |
| match_sets no RLS | HIGH | Score manipulation possible |
| RPCs without SD | MEDIUM | Internal operations may fail |
| elo_history empty | MEDIUM | No audit trail |

## Proposed Solution

### 1. RLS on Sensitive Tables (SPEC-RLS-001)

Add RLS policies following the principle of least privilege:

```
athlete_stats:
  - SELECT: Any authenticated user (public profiles)
  - UPDATE: Own record only (via persons.user_id link)

payments:
  - SELECT: Own payments OR tournament organizer
  - INSERT: Blocked (via payment processor only)
  - UPDATE: Organizer can update status only

match_sets:
  - SELECT: Any authenticated user
  - INSERT/UPDATE/DELETE: Blocked (via scores trigger only)
```

### 2. SECURITY DEFINER on RPCs (SPEC-RPC-001)

Add SECURITY DEFINER with `SET search_path` to all internal RPCs:

```
Benefits:
  - Functions can be called from triggers
  - Functions can be called from other functions
  - Prevents search_path injection attacks

Pattern:
  CREATE FUNCTION ... SECURITY DEFINER
  SET search_path TO extensions, public
  AS $$
    -- Explicit authorization check
    IF NOT authorized THEN RAISE EXCEPTION;
    ...
  $$;
```

### 3. elo_history Trigger (SPEC-ELO-001)

Create trigger to auto-populate audit trail:

```
Trigger: BEFORE UPDATE ON athlete_stats.current_elo
Action: Insert record into elo_history
Fields: previous_elo, new_elo, elo_change, change_type, match_id
```

## Implementation Plan

| Phase | Tasks | Effort |
|-------|-------|--------|
| 1. RLS Tables | 11 tasks | 2 hours |
| 2. RPC Security | 13 tasks | 3 hours |
| 3. elo_history Trigger | 8 tasks | 2 hours |
| 4. Testing | 5 tasks | 1 hour |
| 5. Documentation | 3 tasks | 1 hour |

**Total Estimated Effort**: ~9 hours

## Success Criteria

- [ ] athlete_stats has 2 RLS policies (SELECT, UPDATE)
- [ ] payments has 3 RLS policies (SELECT, INSERT, UPDATE)
- [ ] match_sets has 4 RLS policies (SELECT, INSERT, UPDATE, DELETE)
- [ ] All 10 RPCs have SECURITY DEFINER
- [ ] All RPCs have explicit authorization checks
- [ ] elo_history trigger creates records on ELO change
- [ ] All security tests pass
- [ ] All integration tests pass

## Dependencies

None - can be implemented independently of other changes.

## Rollback Plan

Each migration can be reverted individually:
- `DROP POLICY` for RLS policies
- `ALTER FUNCTION ... RESET` for SECURITY DEFINER
- `DROP TRIGGER` for elo_history trigger

## Files to Create

```
openspec/changes/security-hardening/
├── proposal.md
├── tasks.md
└── specs/
    ├── SPEC-RLS-001-athlete-payments-matchsets.md
    ├── SPEC-RPC-001-security-definer.md
    └── SPEC-ELO-001-elo-history-trigger.md

supabase/migrations/
├── 00000000000048_rls_sensitive_tables.sql
├── 00000000000049_rpc_security_definer.sql
└── 00000000000050_elo_history_trigger.sql

supabase/tests/
└── security_hardening_tests.sql
```
