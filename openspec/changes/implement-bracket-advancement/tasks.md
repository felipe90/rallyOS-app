# Implementation Tasks: implement-bracket-advancement

## Overview

Implements automatic bracket advancement logic that moves winners to the next match when a match is marked as FINISHED.

---

## 1. Migration File Creation

### 1.1 Create Migration File

**Task ID:** `1.1`  
**Description:** Create migration file `00000000000006_bracket_advancement.sql` in `supabase/migrations/`  
**Complexity:** LOW  
**Verification:**
- [x] File exists at `supabase/migrations/00000000000006_bracket_advancement.sql`
- [x] File starts with `-- Migration: 00000000000006_bracket_advancement`

### 1.2 Create advance_bracket_winner Function

**Task ID:** `1.2`  
**Description:** Create PostgreSQL function `advance_bracket_winner()` with `RETURNS TRIGGER` and `SECURITY DEFINER`  
**Complexity:** MED  
**Verification:**
- [x] Function is `CREATE OR REPLACE FUNCTION advance_bracket_winner()`
- [x] Function has `RETURNS TRIGGER`
- [x] Function has `SECURITY DEFINER`

### 1.3 Implement Winner Determination Logic

**Task ID:** `1.3`  
**Description:** Implement logic to count sets won from `sets_json` and determine winner  
**Complexity:** MED  
**Verification:**
- [x] Function counts sets where a > b for entry_a
- [x] Function counts sets where b > a for entry_b
- [x] Function selects winner based on higher set count

### 1.4 Implement Advancement Logic

**Task ID:** `1.4`  
**Description:** Implement logic to place winner in next match's entry slot  
**Complexity:** MED  
**Verification:**
- [x] Function gets `next_match_id` from current match
- [x] Function checks if next match exists (not NULL)
- [x] Function places winner in first empty slot (entry_a_id or entry_b_id)

### 1.5 Implement Status Update for Ready Matches

**Task ID:** `1.5`  
**Description:** Implement logic to set next match status to SCHEDULED when both entries present  
**Complexity:** LOW  
**Verification:**
- [x] Function checks if both entry_a_id and entry_b_id are NOT NULL
- [x] Function updates status to 'SCHEDULED' when both present

### 1.6 Create Trigger

**Task ID:** `1.6`  
**Description:** Create trigger `trg_advance_bracket` on matches table  
**Complexity:** LOW  
**Verification:**
- [x] Trigger is `CREATE TRIGGER trg_advance_bracket`
- [x] Trigger fires `AFTER UPDATE ON matches`
- [x] Trigger fires `FOR EACH ROW`
- [x] Trigger executes `advance_bracket_winner()` function

---

## 2. Migration Verification

### 2.1 Run Migration

**Task ID:** `2.1`  
**Description:** Execute migration against local Supabase instance  
**Complexity:** LOW  
**Verification:**
- [x] `supabase db reset` completes without errors
- [x] No migration conflicts with existing schema

### 2.2 Verify Function Exists

**Task ID:** `2.2`  
**Description:** Query database to confirm function exists  
**Complexity:** LOW  
**Verification:**
- [x] `SELECT proname FROM pg_proc WHERE proname = 'advance_bracket_winner'` returns result

### 2.3 Verify Trigger Exists

**Task ID:** `2.3`  
**Description:** Query database to confirm trigger is attached  
**Complexity:** LOW  
**Verification:**
- [x] `SELECT trigger_name FROM information_schema.triggers WHERE trigger_name = 'trg_advance_bracket'` returns result

---

## 3. Integration Testing

### 3.1 Create Test Bracket Structure

**Task ID:** `3.1`  
**Description:** Create a test bracket with semifinals and final match  
**Complexity:** MED  
**Verification:**
- [x] Create Semi-Final 1 with two entries
- [x] Create Semi-Final 2 with two entries
- [x] Create Final match with next_match_id = NULL
- [x] Link semifinals to final via next_match_id

### 3.2 Test Winner Advancement

**Task ID:** `3.2`  
**Description:** Update semifinal to FINISHED and verify winner advances  
**Complexity:** MED  
**Verification:**
- [x] Update Semi-Final 1 to status = 'FINISHED'
- [x] Query Final match to verify winner entry is in entry_a_id or entry_b_id

### 3.3 Test Status Update to SCHEDULED

**Task ID:** `3.3`  
**Description:** Complete both semifinals and verify final becomes SCHEDULED  
**Complexity:** MED  
**Verification:**
- [x] Complete Semi-Final 1 → winner in Final
- [x] Complete Semi-Final 2 → winner in Final
- [x] Query Final match to verify status = 'SCHEDULED'

### 3.4 Test Final Match Handling

**Task ID:** `3.4`  
**Description:** Verify final match (NULL next_match_id) doesn't cause errors  
**Complexity:** LOW  
**Verification:**
- [x] Update Final match to status = 'FINISHED'
- [x] No errors occur

### 3.5 Test Edge Cases

**Task ID:** `3.5`  
**Description:** Test various edge cases  
**Complexity:** MED  
**Verification:**
- [x] Test when entry_a wins all sets
- [x] Test when entry_b wins all sets
- [x] Test when sets are tied (should pick one deterministically)

---

## Summary

| Phase | Tasks | Total Complexity |
|-------|-------|------------------|
| Migration File Creation | 1.1 - 1.6 | 3 LOW, 3 MED |
| Migration Verification | 2.1 - 2.3 | 3 LOW |
| Integration Testing | 3.1 - 3.5 | 1 LOW, 4 MED |
| **Total** | **14** | **7 LOW, 7 MED** |

---

## Dependencies

- Supabase CLI installed
- Docker running for local Supabase
- Access to `supabase/migrations/` directory

## Rollback

```sql
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;
DROP FUNCTION IF EXISTS advance_bracket_winner();
```
