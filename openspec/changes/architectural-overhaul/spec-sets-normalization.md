# SPEC-SETS-NORMALIZATION: Relational Score Entry

## Purpose

Replace the `sets_json` column in the `scores` table with a normalized `match_sets` table to enable SQL-native analytics, enforce data integrity, and optimize offline-first synchronization.

## Data Model Changes

- **[DELETE] `scores.sets_json`**: This column will be removed.
- **[NEW] `match_sets` table**:
    - `id`: UUID (Primary Key)
    - `match_id`: UUID (FK to `matches.id`)
    - `set_number`: INTEGER (1, 2, 3...)
    - `points_a`: INTEGER
    - `points_b`: INTEGER
    - `is_finished`: BOOLEAN
    - **Constraints**: `UNIQUE(match_id, set_number)`

## Requirements

### Requirement: Score Entry

New scores MUST be recorded in the `match_sets` table.

#### Scenario: Referee enters first set result
- GIVEN a match in LIVE status
- WHEN the referee submits scores for Set 1 (11-8)
- THEN a new record is created in `match_sets` with `set_number = 1`, `points_a = 11`, `points_b = 8`.

### Requirement: Set Completion

The system MUST track which set is currently active.

#### Scenario: Advancing to next set
- GIVEN a match with `match_sets` (Set 1: 11-8, Finished)
- WHEN the match continues
- THEN the system inserts a record for `set_number = 2`.

### Requirement: Analytics Reliability

Aggregated statistics MUST be queryable via standard SQL.

#### Scenario: Career Stats
- GIVEN a player's previous matches
- WHEN querying "Total Sets Won"
- THEN the system sums the count of `match_sets` where the player's entry had more points.

## Offline-First Impact

- **Granular Sync**: Clients can sync individual sets instead of the entire JSON array, reducing payload size and conflict probability.
- **Optimistic UI**: The `match_sets` table will be mirrored in the local SQLite database.
