# SPEC-001: Free Tournament Flow

## Purpose

Support free tournaments where players can register and be confirmed without payment processing.

## Requirements

### Requirement: Tournament Fee Field

The system SHALL have a `fee_amount` field on `tournaments` table, nullable, defaulting to 0.

### Requirement: Auto-Confirm for Free Tournaments

When `fee_amount` is 0 or NULL, entries MUST be automatically set to `CONFIRMED` upon creation.

#### Scenario: Create free tournament

- GIVEN fee_amount = 0 on a tournament
- WHEN an organizer creates the tournament and changes status to REGISTRATION
- THEN any entry created has status = CONFIRMED

#### Scenario: Create paid tournament (post-MVP)

- GIVEN fee_amount > 0 on a tournament
- WHEN an entry is created
- THEN entry status is PENDING_PAYMENT (handled by future payment spec)

### Requirement: Status Transitions

Tournament status MUST follow: DRAFT → REGISTRATION → CHECK_IN → LIVE → COMPLETED

#### Scenario: Tournament lifecycle

- GIVEN a tournament in DRAFT
- WHEN organizer sets status to REGISTRATION
- THEN players can register

- GIVEN a tournament in REGISTRATION
- WHEN organizer sets status to CHECK_IN
- THEN registration closes, check-in begins

- GIVEN a tournament in CHECK_IN
- WHEN organizer sets status to LIVE
- THEN tournament begins, matches can start

- GIVEN a tournament in LIVE
- WHEN all matches are FINISHED
- THEN organizer can set status to COMPLETED
