# SPEC-011: Community Feed

## Purpose

Define the activity feed system for tournament events and announcements.

## Requirements

### Requirement: Feed Visibility

All authenticated users MAY view the community feed for a tournament.

#### Scenario: User views tournament feed

- GIVEN an authenticated user
- WHEN they query the community_feed for a tournament
- THEN all feed entries are returned in chronological order (newest first)

### Requirement: Feed Entry Creation

Only tournament staff MAY create feed entries.

#### Scenario: Organizer posts announcement

- GIVEN a tournament organizer
- WHEN they create a feed entry with event_type = 'ANNOUNCEMENT'
- THEN the entry is created

#### Scenario: Referee logs match completion

- GIVEN a referee
- WHEN a match finishes
- THEN a feed entry is automatically created with event_type = 'MATCH_COMPLETED'

### Requirement: Feed Event Types

The system SHALL support the following event types:

| Event Type | Description | Auto-generated |
|------------|-------------|----------------|
| ANNOUNCEMENT | Organizer announcement | No |
| MATCH_COMPLETED | Match finished | Yes |
| ENTRY_REGISTERED | New player registered | Yes |
| ENTRY_CANCELLED | Player cancelled | Yes |
| BRACKET_GENERATED | Bracket created | Yes |
| TOURNAMENT_STARTED | Tournament went LIVE | Yes |
| TOURNAMENT_COMPLETED | Tournament finished | Yes |

#### Scenario: Auto-generated entry on registration

- GIVEN a new entry is created
- WHEN the entry is confirmed
- THEN an ENTRY_REGISTERED feed entry is created automatically

### Requirement: Feed Payload

Feed entries MUST include:

- `event_type`: The type of event
- `timestamp`: When the event occurred
- `actor_id`: Who/what triggered the event (user_id or system)
- `payload_json`: Event-specific data

#### Scenario: Match completed payload

- GIVEN a match between entry_a and entry_b finishes
- WHEN MATCH_COMPLETED feed entry is created
- THEN payload includes {match_id, winner_entry_id, score_summary}
