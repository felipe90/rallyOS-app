# SPEC-008: Sports CRUD con RLS

## Purpose

Define RLS policies for the `sports` table to secure sport management.

## Requirements

### Requirement: Enable RLS on Sports

The system SHALL enable Row Level Security on the `sports` table.

### Requirement: Sport Visibility

All authenticated users MUST be able to SELECT sports for tournament creation.

#### Scenario: User views sports list

- GIVEN an authenticated user
- WHEN the user queries the sports table
- THEN all sports are returned

### Requirement: Sport Management

Only platform administrators (via service role) or a designated "SPORTS_ADMIN" role SHOULD be able to INSERT, UPDATE, or DELETE sports.

#### Scenario: Admin creates sport

- GIVEN an authenticated admin user with SPORTS_ADMIN role
- WHEN they create a new sport (e.g., "Pickleball")
- THEN the sport is created

#### Scenario: Regular user cannot create sport

- GIVEN an authenticated regular user
- WHEN they attempt to create a sport
- THEN the creation is denied by RLS

### Requirement: Seeded Sports

The system SHALL have pre-seeded sports: Tennis, Padel, Pickleball, Squash, Badminton.

#### Scenario: Default sports exist

- GIVEN the system is initialized
- WHEN a user queries sports
- THEN at least Tennis, Padel exist as default options
