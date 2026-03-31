# SPEC-002: Attendance/Check-In

## Purpose

Allow organizers to confirm player attendance before generating brackets.

## Requirements

### Requirement: Attendance Confirmation

The system SHALL allow organizers to mark entries as "attended" during CHECK_IN phase.

#### Scenario: Organizer confirms attendance

- GIVEN a tournament in CHECK_IN status
- WHEN organizer confirms an entry's attendance
- THEN entry status remains CONFIRMED and `checked_in_at` timestamp is set

#### Scenario: Organizer marks as no-show

- GIVEN a tournament in CHECK_IN status
- WHEN organizer marks an entry as NOT_ATTENDED
- THEN entry status changes to CANCELLED (not included in bracket)

### Requirement: Only Confirmed Entries in Bracket

Only entries with CONFIRMED status at time of bracket generation SHALL be included in the bracket.

#### Scenario: Bracket excludes non-attended

- GIVEN a tournament in CHECK_IN with some entries marked NOT_ATTENDED
- WHEN organizer generates bracket
- THEN only CONFIRMED entries are included in matches

### Requirement: Pre-Backet Attendance Lock

Once bracket is generated, attendance changes MUST NOT modify existing match entries.

#### Scenario: Attendance locked after bracket

- GIVEN a tournament with generated bracket (status = LIVE)
- WHEN organizer attempts to change attendance
- THEN the change is rejected with an error
