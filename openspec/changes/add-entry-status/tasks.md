# Implementation Tasks: add-entry-status

## Overview

Implements the entry status state machine for `tournament_entries` to track payment lifecycle from registration through confirmation.

---

## 1. Database Migration

### 1.1 Create Migration File

**Task ID:** `1.1`  
**Description:** Create migration file `00000000000003_add_entry_status.sql` in `supabase/migrations/`  
**Complexity:** LOW  
**Verification:**
- [x] File exists at `supabase/migrations/00000000000003_add_entry_status.sql`
- [x] File starts with `-- Migration: 00000000000003_add_entry_status`

### 1.2 Create Enum Type entry_status

**Task ID:** `1.2`  
**Description:** Create PostgreSQL enum type `entry_status` with values: `'PENDING_PAYMENT'`, `'CONFIRMED'`, `'CANCELLED'`  
**Complexity:** LOW  
**Verification:**
- [x] Migration contains `CREATE TYPE entry_status AS ENUM (...)`
- [x] All three values present in correct order
- [x] Run `SELECT enumlabel FROM pg_enum WHERE enumtypid = 'entry_status'::regtype` confirms values

### 1.3 Add Status Column

**Task ID:** `1.3`  
**Description:** Add column `status` to `tournament_entries` table with default `'PENDING_PAYMENT'`  
**Complexity:** LOW  
**Verification:**
- [x] Migration contains `ALTER TABLE tournament_entries ADD COLUMN status entry_status NOT NULL DEFAULT 'PENDING_PAYMENT'`
- [x] Column is NOT NULL
- [x] Default value enforced at database level

### 1.4 Add fee_amount_snap Column

**Task ID:** `1.4`  
**Description:** Add column `fee_amount_snap` (INTEGER) to capture tournament fee at registration time  
**Complexity:** LOW  
**Verification:**
- [x] Migration contains `ALTER TABLE tournament_entries ADD COLUMN fee_amount_snap INTEGER`
- [x] Column accepts NULL (price may not be set for all entries)
- [x] Column is INTEGER (stored in cents)

### 1.5 Add RLS Policy for Status Updates

**Task ID:** `1.5`  
**Description:** Add RLS policy allowing only entry owner OR ORGANIZER role to UPDATE `status` column  
**Complexity:** MED  
**Verification:**
- [x] Policy checks `(auth.uid() = user_id) OR (hasOrganizerRole(...))`
- [x] Policy applies to UPDATE only (not SELECT/INSERT)
- [x] Existing SELECT policy remains unchanged

---

## 2. Migration Verification

### 2.1 Run Migration

**Task ID:** `2.1`  
**Description:** Execute migration against local Supabase instance  
**Complexity:** LOW  
**Verification:**
- [x] `supabase db reset` completes without errors
- [x] No migration conflicts with existing schema
- [x] All previous migrations still intact

### 2.2 Verify Columns Exist with Correct Defaults

**Task ID:** `2.2`  
**Description:** Query database to confirm columns exist with correct types and defaults  
**Complexity:** LOW  
**Verification:**
- [x] `\d tournament_entries` shows `status` column as `entry_status` type
- [x] `\d tournament_entries` shows `fee_amount_snap` column as `integer`
- [x] `SELECT column_default FROM information_schema.columns WHERE table_name = 'tournament_entries' AND column_name = 'status'` returns `'PENDING_PAYMENT'`

### 2.3 Test INSERT Creates PENDING_PAYMENT by Default

**Task ID:** `2.3`  
**Description:** Insert a test entry without specifying status and verify default assignment  
**Complexity:** LOW  
**Verification:**
- [x] INSERT without status column succeeds
- [x] `SELECT status FROM tournament_entries WHERE id = <new_id>` returns `'PENDING_PAYMENT'`
- [x] Cleanup test entry after verification

---

## 3. Seed Data Update

### 3.1 Update seed.sql for Existing Entries

**Task ID:** `3.1`  
**Description:** Update `supabase/seed.sql` to set `status = 'CONFIRMED'` for all existing entries (matching SUCCEEDED payments)  
**Complexity:** LOW  
**Verification:**
- [x] seed.sql contains `status = 'CONFIRMED'` for entry inserts
- [x] All tournament_entries inserts in seed have status set

### 3.2 Add fee_amount_snap Values

**Task ID:** `3.2`  
**Description:** Add `fee_amount_snap` values to seed entries matching tournament fees  
**Complexity:** LOW  
**Verification:**
- [x] Each seed entry has `fee_amount_snap` set
- [x] Values are reasonable integers (tournament fee in cents)
- [x] Values match corresponding tournament fees

### 3.3 Verify Seed Loads Correctly

**Task ID:** `3.3`  
**Description:** Run `supabase db reset` and verify all seed entries have correct status  
**Complexity:** LOW  
**Verification:**
- [x] `supabase db reset` completes successfully
- [x] `SELECT status, COUNT(*) FROM tournament_entries GROUP BY status` shows all entries as `'CONFIRMED'`
- [x] `SELECT fee_amount_snap FROM tournament_entries` returns no NULLs for entries

---

## 4. Security Tests

### 4.1 Add Test Case for Entry Status Transitions

**Task ID:** `4.1`  
**Description:** Add test cases in `supabase/tests/security_tests.sql` for status update scenarios  
**Complexity:** MED  
**Verification:**
- [x] Test: Owner can UPDATE status from PENDING_PAYMENT to CONFIRMED
- [x] Test: Owner can UPDATE status from PENDING_PAYMENT to CANCELLED
- [x] Test: ORGANIZER can UPDATE another user's entry status
- [x] All tests pass with `psql ... -f supabase/tests/security_tests.sql`

### 4.2 Verify RLS Blocks Non-Owners from Changing Status

**Task ID:** `4.2`  
**Description:** Add test case confirming RLS blocks authenticated non-owners from updating status  
**Complexity:** MED  
**Verification:**
- [x] Test: Authenticated user (not owner, not organizer) cannot UPDATE status
- [x] Test: Unauthenticated user cannot UPDATE status
- [x] Test confirms RLS returns 0 rows affected
- [x] All security tests pass

---

## Summary

| Phase | Tasks | Total Complexity |
|-------|-------|------------------|
| Database Migration | 1.1 - 1.5 | 1 LOW, 1 MED |
| Migration Verification | 2.1 - 2.3 | 3 LOW |
| Seed Data Update | 3.1 - 3.3 | 3 LOW |
| Security Tests | 4.1 - 4.2 | 2 MED |
| **Total** | **14** | **9 LOW, 2 MED** |

---

## Dependencies

- Supabase CLI installed
- Docker running for local Supabase
- Access to `supabase/migrations/` directory
- Access to `supabase/seed.sql`
- Access to `supabase/tests/security_tests.sql`

## Rollback

```sql
ALTER TABLE tournament_entries DROP COLUMN IF EXISTS status;
ALTER TABLE tournament_entries DROP COLUMN IF EXISTS fee_amount_snap;
DROP TYPE IF EXISTS entry_status;
```
