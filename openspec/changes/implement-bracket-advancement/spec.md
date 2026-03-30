# Delta for Bracket Advancement Logic

## Purpose

Implements automatic tournament bracket progression. When a match is marked as `FINISHED`, the winner automatically advances to the next match in the bracket via the `next_match_id` linked list, enabling seamless tournament flow without manual bracket management.

---

## ADDED Requirements

### Requirement: Winner Determination by Sets

The system SHALL determine the winner of a match by counting sets won in the `sets_json` field. The entry with more sets won SHALL be considered the winner.

### Requirement: Winner Advancement to Next Match

When a match status changes to `FINISHED`, the system SHALL:
1. Identify the winner based on sets won
2. Find the next match via `matches.next_match_id`
3. Place the winner's `entry_id` in the first available slot (`entry_a_id` or `entry_b_id`) of the next match
4. If both slots in the next match are now filled, set the status to `SCHEDULED`

### Requirement: NULL Safety for Final Match

The system SHALL handle the case where `next_match_id` is NULL (final match of bracket) by not attempting any advancement.

### Requirement: Trigger Execution

The system SHALL execute the advancement logic via a database trigger that fires AFTER each UPDATE to the `matches` table, only when `status` changes to `FINISHED`.

---

## ADDED Scenarios

### Scenario: Winner advances from semifinal to final

- GIVEN a bracket with Semi-Final 1, Semi-Final 2, and Final
- AND Semi-Final 1 has `entry_a_id` = Entry1, `entry_b_id` = Entry2
- AND Semi-Final 1 has `next_match_id` pointing to Final
- WHEN Semi-Final 1 is updated to `status = 'FINISHED'`
- AND Entry1 won more sets than Entry2 in `sets_json`
- THEN Entry1's `entry_id` SHALL be placed in Final's `entry_a_id` or first empty slot

### Scenario: Next match status becomes SCHEDULED when both entries present

- GIVEN a Final match with `entry_a_id` = NULL, `entry_b_id` = NULL
- AND Final has `status` = 'WAITING' (or any non-SCHEDULED status)
- WHEN winner from Semi-Final 1 advances to Final (now has one entry)
- AND winner from Semi-Final 2 advances to Final (now has both entries)
- THEN Final's status SHALL be automatically updated to `SCHEDULED`

### Scenario: Final match (no next_match_id) handled gracefully

- GIVEN a Final match with `next_match_id` = NULL
- WHEN the Final match is updated to `status = 'FINISHED'`
- THEN no error SHALL occur
- AND no attempt SHALL be made to advance the winner

### Scenario: Winner determined by sets count

- GIVEN a match with `sets_json` = [{"a": 11, "b": 9}, {"a": 8, "b": 11}, {"a": 11, "b": 7}]
- WHEN the match status is updated to `FINISHED`
- THEN entry_b SHALL be the winner (won 2 sets vs 1)
- AND entry_b's `entry_id` SHALL advance to the next match

### Scenario: Trigger only fires on status change to FINISHED

- GIVEN a match with `status` = 'LIVE'
- WHEN the match is updated but `status` remains 'LIVE'
- THEN the trigger SHALL NOT execute advancement logic

---

## Migration Artifacts

| File | Purpose |
|------|---------|
| `supabase/migrations/00000000000006_bracket_advancement.sql` | Creates trigger function and attaches to matches table |

---

## Data Flow

```
Match Update (FINISHED)
    │
    ▼
Trigger: trg_advance_bracket
    │
    ▼
Determine Winner (count sets_json)
    │
    ▼
Get next_match_id
    │
    ├── NULL? ──► Exit (Final match)
    │
    └── NOT NULL ▼
            Place winner in first empty slot
            │
            ▼
        Both slots filled?
            │
            ├── NO ──► Exit
            │
            └── YES ──► Update status to SCHEDULED
```

---

## Rollback

```sql
DROP TRIGGER IF EXISTS trg_advance_bracket ON matches;
DROP FUNCTION IF EXISTS advance_bracket_winner();
```
