# SPEC-CU01: Tournament Creation

## Purpose

Define requirements for organizer to create a new tournament.

## Requirements

### Requirement: Tournament Creation

An authenticated user MUST be able to create a tournament with basic information.

#### Scenario: Organizer creates free tournament

- GIVEN an authenticated user
- WHEN they create a tournament with name, sport, and fee_amount = 0
- THEN the tournament is created with status = DRAFT
- AND the user is assigned as ORGANIZER in tournament_staff

#### Scenario: Organizer creates paid tournament

- GIVEN an authenticated user
- WHEN they create a tournament with fee_amount > 0
- THEN the tournament is created
- AND entries will require payment (PENDING_PAYMENT)

### Requirement: Tournament Status Transitions

A tournament MUST follow the status lifecycle: DRAFT → REGISTRATION → CHECK_IN → LIVE → COMPLETED

#### Scenario: Transition to REGISTRATION

- GIVEN a tournament in DRAFT
- WHEN organizer changes status to REGISTRATION
- THEN players can register

#### Scenario: Transition to CHECK_IN

- GIVEN a tournament in REGISTRATION
- WHEN organizer changes status to CHECK_IN
- THEN registration closes and check-in begins

#### Scenario: Transition to LIVE

- GIVEN a tournament in CHECK_IN
- WHEN organizer changes status to LIVE
- THEN bracket is generated and matches can start

#### Scenario: Transition to COMPLETED

- GIVEN a tournament in LIVE with all matches finished
- WHEN organizer changes status to COMPLETED
- THEN tournament is locked
