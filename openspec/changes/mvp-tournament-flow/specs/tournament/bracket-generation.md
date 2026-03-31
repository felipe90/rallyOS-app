# SPEC-003: Bracket Generation

## Purpose

Automatically generate single-elimination bracket matches from confirmed entries.

## Requirements

### Requirement: Generate Matches from Entries

The system SHALL generate `matches` records for a category based on CONFIRMED entries when bracket is generated.

#### Scenario: Generate bracket with power-of-2 entries

- GIVEN a category with 8 CONFIRMED entries
- WHEN organizer triggers bracket generation
- THEN 7 matches are created (8 → 4 → 2 → 1)

#### Scenario: Generate bracket with non-power-of-2 entries

- GIVEN a category with 7 CONFIRMED entries
- WHEN organizer triggers bracket generation
- THEN system adds BYE for entry #8, creates matches with BYE automatically winning

### Requirement: Link Matches via next_match_id

Each match SHALL link to its winner's destination via `next_match_id` (linked list structure).

#### Scenario: Bracket structure

- GIVEN 8 entries in a bracket
- WHEN matches are generated
- THEN Semi1.next_match_id → Final, Semi2.next_match_id → Final

### Requirement: Seeding by ELO

Entries SHALL be seeded by `current_elo` (highest seeds play lowest seeds in first round).

#### Scenario: Seeding order

- GIVEN 8 entries with ELOs [1200, 1100, 1050, 1000, 950, 900, 850, 800]
- WHEN bracket is generated
- THEN match 1: 1200 vs 800, match 2: 1100 vs 850, etc.

### Requirement: Bracket Lock

Once generated, bracket matches MUST NOT be modified except for score entry.

#### Scenario: Cannot modify bracket after generation

- GIVEN a generated bracket
- WHEN organizer attempts to change match pairings
- THEN the changes are rejected
