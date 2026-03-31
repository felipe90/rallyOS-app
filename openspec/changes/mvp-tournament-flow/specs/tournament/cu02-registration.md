# SPEC-CU02: Tournament Registration

## Purpose

Define requirements for player registration in tournaments.

## Requirements

### Requirement: Player Registration

An authenticated player MUST be able to register for a tournament in REGISTRATION status.

#### Scenario: Player registers in free tournament

- GIVEN a tournament in REGISTRATION status with fee_amount = 0
- WHEN a player creates an entry
- THEN the entry status is automatically CONFIRMED

#### Scenario: Player registers in paid tournament

- GIVEN a tournament in REGISTRATION status with fee_amount > 0
- WHEN a player creates an entry
- THEN the entry status is PENDING_PAYMENT

### Requirement: Registration Validation

The system MUST validate player eligibility before registration.

#### Scenario: Player within ELO range

- GIVEN a category with elo_min = 800 and elo_max = 1200
- WHEN a player with ELO 1000 registers
- THEN the registration succeeds

#### Scenario: Player outside ELO range

- GIVEN a category with elo_min = 800 and elo_max = 1200
- WHEN a player with ELO 1500 registers
- THEN the registration is rejected

### Requirement: Single Registration per Category

The system MUST NOT allow the same person to register twice in the same category.

#### Scenario: Duplicate registration attempt

- GIVEN a player already registered in category Men's Singles
- WHEN they attempt to register again in the same category
- THEN the registration is rejected (SPEC-006)
