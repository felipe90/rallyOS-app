# SPEC-CU03: Attendance Check-In

## Purpose

Define requirements for organizer to confirm player attendance.

## Requirements

### Requirement: Attendance Confirmation

An organizer MUST be able to confirm attendance for registered players.

#### Scenario: Confirm player attendance

- GIVEN a tournament in CHECK_IN status
- WHEN organizer marks an entry as present
- THEN checked_in_at timestamp is set

#### Scenario: Mark player as no-show

- GIVEN a tournament in CHECK_IN status
- WHEN organizer marks an entry as absent
- THEN entry status changes to CANCELLED

### Requirement: Only Confirmed Entries in Bracket

Only entries with CONFIRMED status SHALL be included in bracket generation.

#### Scenario: Bracket excludes non-attended

- GIVEN a tournament with some entries marked as CANCELLED
- WHEN bracket is generated
- THEN only CONFIRMED entries are included

### Requirement: Pre-Bracket Lock

Once bracket is generated, attendance changes MUST NOT be allowed.

#### Scenario: Attendance locked after bracket

- GIVEN a tournament with status = LIVE
- WHEN organizer attempts to change attendance
- THEN the change is rejected
