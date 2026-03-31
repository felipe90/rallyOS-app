# SPEC-CU05: Score Entry

## Purpose

Define requirements for referee score entry.

## Requirements

### Requirement: Score Entry Authorization

Only assigned referee or organizer MAY update scores.

#### Scenario: Referee enters score

- GIVEN a match in LIVE status with referee assigned
- WHEN referee updates scores
- THEN the scores are saved

#### Scenario: Non-referee denied

- GIVEN a match in LIVE status
- WHEN a non-referee attempts to update scores
- THEN the update is denied by RLS

### Requirement: Score Tracking

The system MUST track scores per set in sets_json.

#### Scenario: Multiple sets

- GIVEN a match with sets [6-3, 3-6, 6-4]
- WHEN scores are saved
- THEN sets_json contains all set results
- AND current_set = 3

### Requirement: Winner Declaration

The system MUST determine winner when match ends.

#### Scenario: Normal finish

- GIVEN sets_json = [{"a": 6, "b": 3}, {"a": 3, "b": 6}, {"a": 6, "b": 4}]
- WHEN match status is set to FINISHED
- THEN entry_a is declared winner (2 sets to 1)

#### Scenario: Walkover

- GIVEN one entry doesn't show
- WHEN organizer sets status to W_O
- THEN the present entry is declared winner
