# SPEC-CU10: Activity Feed

## Purpose

Define requirements for tournament activity feed.

## Requirements

### Requirement: Feed Visibility

All authenticated users MUST be able to view tournament feed.

#### Scenario: User views feed

- GIVEN an authenticated user
- WHEN they view tournament feed
- THEN events are shown in reverse chronological order

### Requirement: Event Types

The system MUST support the following event types:

| Event Type | Description | Auto-generated |
|------------|-------------|----------------|
| ANNOUNCEMENT | Organizer message | No |
| ENTRY_REGISTERED | New registration | Yes |
| ENTRY_CANCELLED | Registration cancelled | Yes |
| MATCH_COMPLETED | Match finished | Yes |
| BRACKET_GENERATED | Bracket created | Yes |
| TOURNAMENT_STARTED | Tournament went LIVE | Yes |
| TOURNAMENT_COMPLETED | Tournament finished | Yes |

#### Scenario: Auto-entry on registration

- GIVEN a new entry is created
- WHEN entry status is CONFIRMED
- THEN ENTRY_REGISTERED event is auto-generated

### Requirement: Event Payload

Each feed entry MUST include event metadata.

#### Scenario: MATCH_COMPLETED payload

- GIVEN a match finishes
- WHEN event is created
- THEN payload includes: match_id, winner_name, score_summary
