# SPEC-IDENTITY: Unified Athlete Profiles & Auth

## Purpose

Unify the identity system to support both Supabase Auth users and "Shadow Profiles" (unregistered players) while maintaining consistent ELO tracking and RLS security.

## Data Model Changes

- **`persons` table**: Acts as the master "Profile" for all athletes.
- **`user_id` column**: Optional link to `auth.users(id)`. 
- **Consistency Rule**: A `user_id` MUST NOT be linked to more than one `person_id`.
- **Tournament Staff**: `tournament_staff` will link to `auth.users(id)` for security but SHOULD have a corresponding `person_id` if they are also athletes.

## Requirements

### Requirement: Profile Creation

The system MUST allow creating a profile without an associated `auth.user`.

#### Scenario: Registering a friend (Shadow Profile)
- GIVEN a tournament organizer
- WHEN they add a player "Juan Perez" who doesn't have an account
- THEN a new `persons` record is created with `user_id = NULL`
- AND Juan Perez can be added to matches and receive ELO.

### Requirement: Account Linking

A "Shadow Profile" MUST be linkable to an `auth.user` when they sign up.

#### Scenario: Player claims their profile
- GIVEN a `persons` record for "Juan Perez" (`user_id = NULL`)
- WHEN Juan signs up and "claims" his profile (via admin or verified email)
- THEN `persons.user_id` is updated to Juan's `auth.uid()`
- AND all previous match history and ELO are preserved.

### Requirement: Staff Authorization

Administrative actions (Match Score, Tournament Config) MUST be tied to `auth.users` for RLS.

#### Scenario: Accessing Staff Table
- GIVEN a table `tournament_staff`
- WHEN checking permissions
- THEN the system uses `auth.uid()` to identify the role (ORGANIZER / REFEREE).

## Security (RLS)

- **Read**: `persons` are public (via `public_tournament_snapshot`).
- **Write**: 
    - A user can only update their OWN `persons` record (where `user_id = auth.uid()`).
    - Organizers can update `persons` records for players in their tournaments.
