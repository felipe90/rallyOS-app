# SPEC-REAL-ELO: Accurate Competitive Rating Engine

## Purpose

Replace the placeholder "Entry A Wins" logic with a robust, set-based competitive ranking system (ELO) that maintains integrity, rewards skilled performance, and scales with player volume.

## Data Model Changes

- **`athlete_stats` table**: Tracks `matches_played` to determine the dynamic K-Factor.
- **`elo_history` table**: Provides a ledger for auditing rating changes and generating progress graphs.
- **`match_sets` table**: Used as the source for winner determination.

## Requirements

### Requirement: Real Winner Detection

The engine MUST determine the winner by counting sets won from the `match_sets` table.

#### Scenario: Winner detected in sets comparison
- GIVEN a match where `match_sets` has (Set 1: 11-8, Set 2: 9-11, Set 3: 11-6).
- WHEN the match is set to FINISHED.
- THEN the system detects `Entry A` won 2 sets vs `Entry B` won 1 set.
- AND `Entry A` is selected as the winner for ELO calculation.

### Requirement: Dynamic K-Factor

The rating engine MUST adjust the K-Factor tier based on player experience.

#### Scenario: Professional vs Amateur tiers
- GIVEN "Andres" has played 45 matches and "Miguel" has played 10 matches.
- WHEN a match between them finishes.
- THEN Andres' rating change uses `K = 24` (Tier 2).
- AND Miguel's rating change uses `K = 32` (Tier 1).

### Requirement: Expected Score Formula

The system MUST use the standard ELO formula to calculate the win probability before applying changes.

#### Scenario: Upset Win
- GIVEN a highly-rated player (1200) vs a low-rated player (800).
- WHEN the low-rated player wins.
- THEN the low-rated player receives a massive rating boost (near +32).
- AND the high-rated player receives a corresponding major drop.

## Formula Implementation (Server-Side)

```
Expected Score = 1 / (1 + 10^((Opponent Rating - Player Rating) / 400))
New Rating = Old Rating + K × (Actual Result - Expected Score)
```

Where `Actual Result` is `1` for the winner and `0` for the loser.
Matches ending in a DRAW (if applicable per sport) result in `Actual Result = 0.5`.
