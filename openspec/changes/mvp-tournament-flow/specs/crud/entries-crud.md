# SPEC-010: Tournament Entries CRUD

## Purpose

Define RLS policies and validation for the `tournament_entries` table.

## Requirements

### Requirement: Entry Visibility

All authenticated users MUST be able to SELECT entries for viewing tournament registrations.

#### Scenario: User views tournament entries

- GIVEN an authenticated user viewing a tournament
- WHEN they query entries
- THEN all entries for that tournament are returned

### Requirement: Entry Creation

Authenticated users MAY create entries in tournaments in REGISTRATION status.

#### Scenario: Player creates entry

- GIVEN a tournament in REGISTRATION status
- WHEN an authenticated user creates an entry
- THEN the entry is created with status based on fee_amount

#### Scenario: Tournament not in registration

- GIVEN a tournament NOT in REGISTRATION status
- WHEN a user attempts to create an entry
- THEN the creation is denied with error

#### Scenario: User already has entry in this category

- GIVEN a user already registered in a category
- WHEN they attempt to create another entry in the same category
- THEN the creation is denied by SPEC-006 (duplicate registration prevention)

### Requirement: Entry Modification

Only entry owner (via entry_members) or organizer MAY update entries.

#### Scenario: Entry owner updates display_name

- GIVEN an authenticated user who is a member of an entry
- WHEN they update the entry's display_name
- THEN the update succeeds

#### Scenario: Organizer updates entry

- GIVEN a tournament organizer
- WHEN they update an entry's status
- THEN the update succeeds

### Requirement: Entry Cancellation

Users MAY cancel their own entries before tournament goes LIVE.

#### Scenario: User cancels own entry

- GIVEN a user with an entry in REGISTRATION status
- WHEN they cancel the entry
- THEN status changes to CANCELLED

#### Scenario: Cancel after LIVE

- GIVEN a tournament in LIVE status
- WHEN a user attempts to cancel their entry
- THEN the cancellation is denied
