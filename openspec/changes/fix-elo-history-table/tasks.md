# Implementation Tasks: fix-elo-history-table

## Tasks

### 1. Database Migration

**Task ID:** 1  
**Description:** Create migration file to add the missing `elo_history` table with proper schema, enum type, and indexes.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- Migration file created at `supabase/migrations/00000000000002_add_elo_history.sql`
- File contains enum type, table definition, and indexes

#### 1.1 Create Migration File

**Task ID:** 1.1  
**Description:** Create `supabase/migrations/00000000000002_add_elo_history.sql` with all required schema elements.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- File exists at correct path
- File begins with `-- Migration: Add elo_history table` comment

#### 1.2 Create Enum Type `elo_change_type`

**Task ID:** 1.2  
**Description:** Add enum type for the `change_type` field with values 'MATCH_WIN', 'MATCH_LOSS', 'ADJUSTMENT'.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- `SELECT enumlabel FROM pg_enum WHERE enumtypid = 'elo_change_type'::regtype;` returns all three values
- Enum type referenced correctly in table definition

#### 1.3 Create Table `elo_history`

**Task ID:** 1.3  
**Description:** Create `elo_history` table with columns: id, person_id, sport_id, match_id, previous_elo, new_elo, elo_change, change_type, created_at.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- Table exists: `SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'elo_history');` returns true
- All columns present with correct types
- FK constraints on person_id and sport_id work correctly
- match_id is nullable (ON DELETE SET NULL)

#### 1.4 Add Indexes

**Task ID:** 1.4  
**Description:** Create indexes for efficient ELO history queries.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- `idx_elo_history_person_sport` exists on `(person_id, sport_id)`
- `idx_elo_history_match_id` exists on `match_id`
- Query `SELECT indexname FROM pg_indexes WHERE tablename = 'elo_history';` returns both indexes

#### 1.5 Verify RLS Policy Already Exists

**Task ID:** 1.5  
**Description:** Confirm RLS policy for `elo_history` is already configured in `00000000000001_security_policies.sql`.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- `ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;` at line 29 (already applied)
- SELECT policy exists at lines 57-63: `"Elo history is read only for users"`
- No INSERT policy means client inserts blocked by RLS (triggers bypass via SECURITY DEFINER)

---

### 2. Migration Verification

**Task ID:** 2  
**Description:** Apply migration and verify all schema elements are correctly created.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- `supabase db reset` completes without errors
- All tables, columns, indexes, and constraints are present

#### 2.1 Run `supabase db reset`

**Task ID:** 2.1  
**Description:** Apply all migrations including the new `elo_history` table.  
**Estimated Complexity:** MEDIUM  
**Verification Steps:**
- Command completes successfully (exit code 0)
- No SQL errors in output
- Database is in consistent state

#### 2.2 Verify Table Exists and Has Correct Columns

**Task ID:** 2.2  
**Description:** Query system catalog to confirm table structure matches spec.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- `SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'elo_history' ORDER BY ordinal_position;`
- Returns 9 columns with correct types and nullability
- FK constraints properly configured

#### 2.3 Run Existing Security Tests

**Task ID:** 2.3  
**Description:** Execute security tests to verify RLS policies work correctly.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- Run: `psql postgres://postgres:postgres@localhost:54322/postgres -f supabase/tests/security_tests.sql`
- All tests pass
- ELO history SELECT policy allows authenticated users
- ELO history INSERT/UPDATE/DELETE blocked for clients

---

### 3. Documentation Update

**Task ID:** 3  
**Description:** Update domain model documentation to align with actual schema.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- `docs/DOMAIN_MODEL_V2.md` reflects `elo_history` table structure
- EloLedger entity documented with correct fields

#### 3.1 Update DOMAIN_MODEL_V2.md

**Task ID:** 3.1  
**Description:** Align EloLedger entity in domain model with actual `elo_history` schema.  
**Estimated Complexity:** LOW  
**Verification Steps:**
- Document mentions `elo_history` table (or EloLedger) with fields:
  - `previousElo`, `newElo`
  - `changeType` with values: MATCH_WIN, MATCH_LOSS, ADJUSTMENT
  - `matchId` (nullable for manual adjustments)
- File is updated and formatted correctly

---

## Success Criteria Checklist

- [ ] Migration file created: `supabase/migrations/00000000000002_add_elo_history.sql`
- [ ] Enum type `elo_change_type` created with 3 values
- [ ] Table `elo_history` created with all 9 columns
- [ ] Index `idx_elo_history_person_sport` on `(person_id, sport_id)`
- [ ] Index `idx_elo_history_match_id` on `match_id`
- [ ] RLS enabled on `elo_history` (already in 00000000000001)
- [ ] SELECT policy exists for authenticated users
- [ ] No INSERT/UPDATE/DELETE policies (blocked by RLS)
- [ ] `supabase db reset` completes without errors
- [ ] `docs/DOMAIN_MODEL_V2.md` updated to reflect schema

---

## Dependencies

- **Prerequisites:** None (self-contained migration)
- **Follow-up:** Verify match completion trigger (`process_match_completion`) can insert into `elo_history` without errors

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Migration order conflict | LOW | MEDIUM | New migration numbered 00000000000002 runs after existing migrations |
| Existing code expects different schema | LOW | HIGH | Spec matches current function references in `process_match_completion` and `rollback_match` |
| Backward compatibility | LOW | LOW | New table doesn't affect existing functionality |
