# SPEC-CU08: Tournament Closure

## Purpose

Define requirements for tournament finalization.

## Requirements

### Requirement: Closure Authorization

Only organizer MAY close a tournament.

#### Scenario: Organizer closes tournament

- GIVEN a tournament in LIVE with all matches finished
- WHEN organizer sets status to COMPLETED
- THEN tournament is closed

### Requirement: Closure Validation

Tournament MUST have all matches completed before closure.

#### Scenario: Closure with pending matches

- GIVEN a tournament in LIVE with pending matches
- WHEN organizer attempts to close
- THEN closure is rejected with error listing pending matches

#### Scenario: Closure with suspended matches

- GIVEN a tournament with SUSPENDED matches
- WHEN organizer attempts to close
- THEN closure is rejected
- AND organizer must resolve suspended matches first

### Requirement: Tournament Lock

Completed tournaments MUST be immutable.

#### Scenario: Cannot modify completed tournament

- GIVEN a tournament with status = COMPLETED
- WHEN any modification is attempted
- THEN the modification is rejected
