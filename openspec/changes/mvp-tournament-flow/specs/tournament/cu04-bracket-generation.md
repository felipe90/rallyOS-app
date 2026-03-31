# SPEC-CU04: Bracket Generation

## Purpose

Define requirements for automatic bracket generation.

## Requirements

### Requirement: Automatic Match Creation

The system MUST generate matches automatically when bracket is requested.

#### Scenario: Generate bracket with power-of-2 entries

- GIVEN a category with 8 CONFIRMED entries
- WHEN organizer generates bracket
- THEN 7 matches are created (8 → 4 → 2 → 1)

#### Scenario: Generate bracket with BYEs

- GIVEN a category with 7 CONFIRMED entries
- WHEN organizer generates bracket
- THEN BYE is assigned to entry #8
- AND first round has 4 real matches + 1 BYE match

### Requirement: ELO-based Seeding

Entries MUST be seeded by ELO for fair bracket placement.

#### Scenario: Seeding order

- GIVEN 8 entries with ELOs [1200, 1100, 1050, 1000, 950, 900, 850, 800]
- WHEN bracket is generated
- THEN match 1: 1200 vs 800
- AND match 2: 1100 vs 850
- AND so on (highest vs lowest)

### Requirement: Match Linking

Matches MUST be linked via next_match_id for bracket advancement.

#### Scenario: Bracket structure

- GIVEN 8 entries
- WHEN bracket is generated
- THEN Semi1.next_match_id → Final
- AND Semi2.next_match_id → Final
