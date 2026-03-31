# SPEC-DETERMINISTIC-BRACKETS: Slot-Based Advancement

## Purpose

Replace the fragile "first empty slot" logic in bracket advancement with a deterministic mapping system to ensure tournament integrity, even in complex bracket structures (Single Elimination, Double Elimination, etc.).

## Data Model Changes

- **[NEW] `winner_to_slot` (ENUM 'A', 'B')**: Added to the `matches` table.
- **[NEW] `loser_to_slot` (ENUM 'A', 'B')**: (Optional) For future Double Elimination / Consolation brackets.
- **`next_match_id`**: Remains the primary link to the next match in the tournament tree.

## Requirements

### Requirement: Deterministic Advancement

The system MUST place the winner of a match into a SPECIFIC slot (`entry_a` or `entry_b`) in the next match.

#### Scenario: Semifinalists advance to Final
- GIVEN a tournament with Match 1 (Semi 1) and Match 2 (Semi 2) both pointing to Match 3 (Final).
- IF Match 1 has `winner_to_slot = 'A'` and Match 2 has `winner_to_slot = 'B'`.
- WHEN Match 1 is FINISHED
- THEN the winner is placed in Match 3 `entry_a_id`, REGARDLESS of whether `entry_b_id` is empty.

### Requirement: Idempotent Updates

The bracket advancement trigger MUST be idempotent to prevent duplicate entries or circular errors.

#### Scenario: Double Update Prevention
- GIVEN a winner already placed in the next match slot.
- WHEN the trigger runs again due to a score verification.
- THEN the system confirms the slot content and exits without creating a duplicate or error.

### Requirement: Round State Management

The `match.status` MUST only change to `SCHEDULED` or `READY` when both slots are filled.

#### Scenario: Ready for play
- GIVEN a match where a winner has been placed in Slot A.
- WHEN a second winner is placed in Slot B.
- THEN the Match status is updated to `SCHEDULED`.

## Structural Integrity

By using explicit slots, the system can reconstruct the entire bracket tree visually with a single recursive query, knowing exactly which branch corresponds to which entry.
