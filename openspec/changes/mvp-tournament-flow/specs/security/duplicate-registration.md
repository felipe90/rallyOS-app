# SPEC-006: Prevent Duplicate Registration

## Purpose

Prevent the same person from being registered multiple times in the same tournament category.

## Requirements

### Requirement: Unique Person per Tournament

The system MUST NOT allow the same `person_id` to be registered (via `entry_members`) in multiple entries within the same tournament category.

#### Scenario: Person registers once

- GIVEN a tournament in REGISTRATION status with an open category
- WHEN a person registers via a single entry
- THEN the registration succeeds

#### Scenario: Same person tries duplicate registration

- GIVEN a tournament where person X is already registered in category Y
- WHEN the system attempts to add person X to a second entry in category Y
- THEN the registration is rejected with an error

#### Scenario: Same person in different categories

- GIVEN a tournament with multiple categories (e.g., Men's Singles, Men's Doubles)
- WHEN a person registers in category A and category B
- THEN both registrations succeed (different categories = different tournaments logically)

#### Scenario: Duplicate detection ignores cancelled entries

- GIVEN a tournament where person X's registration was CANCELLED
- WHEN person X attempts to register again
- THEN the new registration succeeds (cancelled = not registered)
