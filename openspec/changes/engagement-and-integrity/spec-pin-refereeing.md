# SPEC-PIN-REFEREEING: Player-Driven Integrity

## Purpose

Enable match results to be entered directly by players while maintaining data integrity and preventing unauthorized scoring, without the need for constant internet connectivity (Agreement model) or dedicated staff.

## Data Model Changes

- **[NEW] `matches.pin_code`**: A 4-digit numeric string (Example: "8341").
- **[NEW] `matches.pin_generation_secret`**: (Internal) Used for seed-based predictable generation if needed, or simple random storage.

## Requirements

### Requirement: PIN Generation

The system MUST generate a unique, 4-digit PIN for every match created in the tournament.

#### Scenario: Match Creation
- GIVEN a new match is inserted into the `matches` table.
- WHEN the record is saved.
- THEN the system automatically populates `pin_code` with a random 4-digit string.

### Requirement: Score Entry Validation

The system MUST reject score updates from non-staff users unless the correct PIN is provided.

#### Scenario: Player enters score at the court
- GIVEN a player is at the court and has finished the match.
- WHEN they attempt to update the `match_sets` via the app.
- THEN the app MUST prompt for the 4-digit PIN.
- AND the backend MUST verify the PIN matches the `matches` record before accepting the result.

### Requirement: Staff Bypass

The system MUST allow users with the `TournamentStaff` (ORGANIZER/REFEREE) role to update scores WITHOUT a PIN.

#### Scenario: Administrative correction
- GIVEN an organizer correcting a typo in a score.
- WHEN they perform the update.
- THEN the system confirms their role and ignores the PIN requirement.

## UI/UX Integration

- **Dashboard Display**: The match PIN MUST be visible in the Tournament Organizer's dashboard (to be shared with players).
- **Offline Entry**: The app SHOULD cache the PIN locally once the player is assigned to a court and enters it the first time, allowing set-by-set updates without re-entering the PIN if connectivity is lost.
