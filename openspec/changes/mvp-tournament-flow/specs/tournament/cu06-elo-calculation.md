# SPEC-CU06: Automatic ELO Calculation

## Purpose

Define requirements for automatic ELO calculation on match completion.

## Requirements

### Requirement: ELO Calculation Trigger

The system MUST automatically calculate ELO changes when a match finishes.

#### Scenario: Winner gains ELO, loser loses

- GIVEN player A (1000 ELO) vs player B (800 ELO)
- WHEN player A wins
- THEN player A gains ELO (e.g., +8)
- AND player B loses ELO (e.g., -8)

### Requirement: K-Factor Based on Experience

The K-factor MUST vary based on matches played.

| Matches Played | K-Factor |
|----------------|----------|
| 0-29 | 32 |
| 30-99 | 24 |
| 100+ | 16 |

#### Scenario: Novice vs experienced

- GIVEN player A (0 matches, K=32) vs player B (100 matches, K=16)
- WHEN match finishes
- THEN player A's ELO change is larger than player B's

### Requirement: ELO History Ledger

All ELO changes MUST be recorded immutably.

#### Scenario: ELO history recorded

- GIVEN a match finishes
- WHEN ELO is calculated
- THEN INSERT records are created in elo_history
- AND athlete_stats are updated
- AND records are immutable (no UPDATE/DELETE policy)
