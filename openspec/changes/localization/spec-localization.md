# SPEC-LOCALIZATION: Global Readiness & Geographic Filtering

## Purpose

Enable RallyOS to scale internationally by adding a localization layer that allows clubs, tournaments, and players to be categorized and filtered by country/nationality, while maintaining a unified global competitive index (ELO).

## Data Model Changes

- **[NEW] `countries` table**:
    - `id`: UUID (Primary Key)
    - `iso_code`: TEXT (2-letter ISO, e.g., 'CO', 'AR', 'ES')
    - `name`: TEXT NOT NULL
    - `currency_code`: TEXT (e.g., 'COP', 'ARS', 'EUR')
    - `flag_emoji`: TEXT (e.g., '🇨🇴')

- **[MODIFY] `persons` table**: Add `nationality_country_id` (FK to `countries.id`).
- **[MODIFY] `clubs` table**: Add `country_id` (FK to `countries.id`).
- **[MODIFY] `tournaments` table**: Add `country_id` (FK to `countries.id`).

## Requirements

### Requirement: Master Reference Data

The system MUST provide a pre-seeded table of countries for consistent data entry.

#### Scenario: Registering a Club
- GIVEN a club owner creates a new club.
- WHEN they select their location.
- THEN the system provides a list of countries from the `countries` table.

### Requirement: Geographic Inheritance

A tournament SHOULD inherit the country of the club that organizes it, but allowing for manual override (e.g., a "Colombia Open" organized by a Spanish club).

#### Scenario: Creating a Tournament
- GIVEN a Club "Padel Pro" linked to `country_id = 'ES'` (Spain).
- WHEN the Club creates a new tournament.
- THEN the new tournament is initialized with `country_id = 'ES'`.
- AND the organizer can manually change it before the tournament goes LIVE.

### Requirement: Profile Nationality

Players SHOULD be able to display their nationality on their public profile.

#### Scenario: International Ranking
- GIVEN a public tournament leaderboard.
- WHEN the result is displayed.
- THEN the system retrieves the `flag_emoji` from the linked country in the player's `persons` record.

## Multi-Tenancy & Privacy (Future Consideration)

While not enforced in the MVP, this architecture enables the future use of Row Level Security (RLS) policies scoped by `country_id` if local regulatory requirements (e.g., GDPR in Spain vs. local data laws in Argentina) arise.
