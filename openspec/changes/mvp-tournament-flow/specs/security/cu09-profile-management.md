# SPEC-CU09: Player Profile Management

## Purpose

Define requirements for player profile and statistics viewing.

## Requirements

### Requirement: Profile Viewing

An authenticated player MUST be able to view their profile.

#### Scenario: Player views own profile

- GIVEN an authenticated player with linked persons record
- WHEN they view their profile
- THEN they see: first_name, last_name, nickname

### Requirement: Profile Editing

A player MUST be able to edit their own profile.

#### Scenario: Player updates nickname

- GIVEN a player with persons record linked to their user_id
- WHEN they update their nickname
- THEN the update succeeds

#### Scenario: Player cannot edit others' profiles

- GIVEN a player viewing another player's profile
- WHEN they attempt to edit it
- THEN the update is denied by RLS

### Requirement: Statistics Viewing

A player MUST be able to view their ELO statistics.

#### Scenario: Player views statistics

- GIVEN a player with athlete_stats records
- WHEN they view statistics
- THEN they see: current_elo, matches_played per sport
- AND they see ELO history
