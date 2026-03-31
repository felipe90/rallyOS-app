# SPEC-007: Club/Organization Management

## Purpose

Support organization-level grouping of players for tournaments and club management.

## Requirements

### Requirement: Club CRUD

The system SHALL allow creating, reading, updating, and deleting club/organization records.

#### Scenario: User creates club

- GIVEN an authenticated user
- WHEN they create a club with a unique name
- THEN the club is created with the user as owner

#### Scenario: Club name uniqueness

- GIVEN a club named "Club Tennis"
- WHEN another user attempts to create "Club Tennis"
- THEN the creation is rejected (duplicate name)

### Requirement: Club Membership

Players MAY belong to multiple clubs via membership records.

#### Scenario: Player joins club

- GIVEN a club and a person record
- WHEN club owner adds the person as member
- THEN membership is created with role MEMBER

#### Scenario: Player leaves club

- GIVEN a person who is a member of a club
- WHEN they request to leave or owner removes them
- THEN membership is deleted

### Requirement: Club-Based Registration

Entries MAY optionally associate with a club.

#### Scenario: Register as club team

- GIVEN a tournament accepting club entries
- WHEN creating an entry with `club_id` set
- THEN the entry is associated with that club

### Requirement: Club Permissions

Only club owners MAY modify club details and membership.

#### Scenario: Non-owner tries to modify club

- GIVEN a club owned by user A
- WHEN user B attempts to update club details
- THEN the update is denied by RLS
