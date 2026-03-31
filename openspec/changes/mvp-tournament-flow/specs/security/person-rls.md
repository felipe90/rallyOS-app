# SPEC-005: Person CRUD con RLS

## Purpose

Define RLS policies for the `persons` table to secure player profile management.

## Requirements

### Requirement: Enable RLS on Persons

The system SHALL enable Row Level Security on the `persons` table.

### Requirement: Own Profile Access

A user MUST be able to create and manage their own person profile linked to their `auth.uid()`.

#### Scenario: User creates own profile

- GIVEN an authenticated user without a `persons` record
- WHEN the user creates a person record with `user_id` matching their `auth.uid()`
- THEN the record is created successfully

#### Scenario: User views all persons

- GIVEN an authenticated user
- WHEN the user queries the `persons` table
- THEN all person records are returned (needed for tournament registration)

#### Scenario: User updates own profile

- GIVEN an authenticated user with a person record
- WHEN the user updates their own `first_name`, `last_name`, or `nickname`
- THEN the update succeeds

#### Scenario: User cannot update others' profiles

- GIVEN an authenticated user viewing another user's person record
- WHEN the user attempts to update that record
- THEN the update is denied by RLS

### Requirement: Guest Persons Allowed

The system SHALL allow creating person records without a `user_id` (for players registered by organizers without app accounts).

#### Scenario: Organizer creates guest player

- GIVEN an authenticated organizer
- WHEN they create a person record with `user_id = NULL`
- THEN the record is created successfully
