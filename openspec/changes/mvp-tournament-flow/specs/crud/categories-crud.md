# SPEC-009: Categories CRUD con RLS

## Purpose

Define RLS policies for the `categories` table to secure category management within tournaments.

## Requirements

### Requirement: Enable RLS on Categories

The system SHALL enable Row Level Security on the `categories` table.

### Requirement: Category Visibility

All authenticated users MUST be able to SELECT categories for viewing tournaments.

#### Scenario: User views tournament categories

- GIVEN an authenticated user viewing a tournament
- WHEN they query categories
- THEN all categories for that tournament are returned

### Requirement: Category Creation

Only tournament organizers MAY create categories within their tournament.

#### Scenario: Organizer creates category

- GIVEN a user who is ORGANIZER of a tournament
- WHEN they create a category (e.g., "Men's Singles")
- THEN the category is created

#### Scenario: Non-organizer cannot create category

- GIVEN an authenticated user who is NOT organizer
- WHEN they attempt to create a category
- THEN the creation is denied by RLS

### Requirement: Category Modification

Only tournament organizers MAY UPDATE or DELETE categories.

#### Scenario: Organizer updates category

- GIVEN a tournament organizer
- WHEN they update category settings (elo_min, elo_max, mode)
- THEN the update succeeds

#### Scenario: Tournament in LIVE status

- GIVEN a tournament in LIVE status
- WHEN organizer attempts to modify categories
- THEN the modification is denied (categories locked during tournament)

### Requirement: Category Deletion

Organizers MAY delete categories only if no entries are registered.

#### Scenario: Delete empty category

- GIVEN a category with zero entries
- WHEN organizer deletes the category
- THEN the deletion succeeds

#### Scenario: Delete category with entries

- GIVEN a category with registered entries
- WHEN organizer attempts to delete
- THEN the deletion is denied with error
