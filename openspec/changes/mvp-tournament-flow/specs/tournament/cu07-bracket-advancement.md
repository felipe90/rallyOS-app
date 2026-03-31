# SPEC-CU07: Bracket Advancement

## Purpose

Define requirements for automatic winner advancement in bracket.

## Requirements

### Requirement: Winner Advances

The system MUST automatically place the winner in the next match.

#### Scenario: Winner advances to next round

- GIVEN Semi-Final where entry A defeats entry B
- WHEN match status becomes FINISHED
- THEN entry A is placed in the Final match
- AND Final may now have both entries

### Requirement: Empty Slot Detection

The system MUST detect which slot (entry_a or entry_b) is empty.

#### Scenario: Place in empty slot

- GIVEN Final with entry_a = NULL, entry_b = Player C
- WHEN Semi winner Player A advances
- THEN entry_a = Player A

### Requirement: Match Activation

When both entries are present in next match, status becomes SCHEDULED.

#### Scenario: Next match ready

- GIVEN Final with entry_a = Player A, entry_b = Player B
- WHEN both entries are present
- THEN match status = SCHEDULED
- AND referees can be assigned
