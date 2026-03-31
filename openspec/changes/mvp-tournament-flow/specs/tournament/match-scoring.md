# SPEC-004: Match Score Entry

## Purpose

Allow referees to enter match scores and trigger winner declaration with automatic ELO calculation and bracket advancement.

## Requirements

### Requirement: Score Entry by Referee

Only the assigned referee (or organizer) MAY update scores for a match in LIVE status.

#### Scenario: Referee enters score

- GIVEN a match in LIVE status with referee assigned
- WHEN referee updates `sets_json` with set results
- THEN the scores are saved

#### Scenario: Non-referee tries to enter score

- GIVEN a match in LIVE status
- WHEN a non-referee attempts to update scores
- THEN the update is denied by RLS

### Requirement: Declare Winner

The system SHALL determine winner based on sets won vs sets lost from `sets_json`.

#### Scenario: Match finishes normally

- GIVEN a match where entry_a won sets [6-3, 3-6, 6-4]
- WHEN scores are saved and match status set to FINISHED
- THEN entry_a is declared winner

#### Scenario: Walkover (W_O)

- GIVEN a match where one entry doesn't show
- WHEN organizer sets status to W_O
- THEN the present entry is declared winner

### Requirement: Automatic ELO Update

Upon FINISHED status, the system SHALL calculate and record ELO changes for both players.

#### Scenario: ELO calculated on match finish

- GIVEN a match between player A (1000 ELO) and player B (800 ELO)
- WHEN match ends with player A as winner
- THEN elo_history records are created for both players
- AND athlete_stats.current_elo is updated for both

### Requirement: Automatic Bracket Advancement

Upon FINISHED status, the winner SHALL be placed in the next match via `next_match_id`.

#### Scenario: Winner advances to next round

- GIVEN Semi-Final match where entry A defeated entry B
- WHEN match status becomes FINISHED
- THEN entry A is placed in the Final match (entry_a_id or entry_b_id)
